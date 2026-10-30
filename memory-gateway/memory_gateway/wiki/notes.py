"""Wiki note parsing, current-only filtering and chunking."""

import logging
import re
from dataclasses import dataclass, field
from pathlib import Path

import frontmatter

from ..arms.base import count_tokens

NOTE_DIRS = ("decisions", "topics", "people", "orgs", "plans")
MAX_CHUNK_TOKENS = 400
log = logging.getLogger(__name__)
_FM_BODY = re.compile(r"\A\ufeff?---\s*\n.*?\n---[ \t]*(?:\n|\Z)(.*)", re.DOTALL)
_STRIKE = re.compile(r"~~.*?~~", re.DOTALL)
_LINK = re.compile(r"\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]")


@dataclass
class Note:
    path: str  # relative, with .md
    meta: dict
    body: str
    raw: str
    title: str = ""
    tags: list[str] = field(default_factory=list)
    updated: str = ""


def link_target(value: object) -> str:
    """'[[decisions/x|Alias]]' -> 'decisions/x'."""
    s = str(value).strip()
    m = _LINK.search(s)
    s = (m.group(1) if m else s).strip()
    return s[:-3] if s.endswith(".md") else s


def _as_list(v: object) -> list:
    if v is None:
        return []
    return list(v) if isinstance(v, (list, tuple)) else [v]


def parse_post(raw: str, path: object = "") -> frontmatter.Post:
    """Parse frontmatter; on malformed YAML warn and use empty metadata."""
    try:
        return frontmatter.loads(raw)
    except Exception as e:  # yaml.YAMLError and friends
        log.warning("wiki: unparsable frontmatter in %s: %s", path, e)
        m = _FM_BODY.match(raw)
        return frontmatter.Post((m.group(1) if m else raw).strip())


def load_post(path: Path) -> frontmatter.Post:
    return parse_post(path.read_text(encoding="utf-8"), path)


def load_note(root: Path, rel: str) -> Note | None:
    try:
        raw = (root / rel).read_text(encoding="utf-8")
    except (OSError, ValueError):
        return None
    post = parse_post(raw, rel)
    meta = dict(post.metadata)
    return Note(
        path=rel,
        meta=meta,
        body=post.content,
        raw=raw,
        title=str(meta.get("title") or Path(rel).stem),
        tags=[str(t) for t in _as_list(meta.get("tags"))],
        updated=str(meta.get("updated") or ""),
    )


def load_all(root: Path) -> list[Note]:
    notes = []
    for d in NOTE_DIRS:
        if not (root / d).is_dir():
            continue
        for p in sorted((root / d).glob("**/*.md")):
            n = load_note(root, p.relative_to(root).as_posix())
            if n:
                notes.append(n)
    return notes


def current_notes(notes: list[Note]) -> list[Note]:
    superseded = {
        link_target(x) for n in notes for x in _as_list(n.meta.get("supersedes"))
    }
    out = []
    for n in notes:
        if str(n.meta.get("status", "")).lower() in ("superseded", "reversed"):
            continue
        if n.meta.get("superseded_by"):
            continue
        if n.path[:-3] in superseded:
            continue
        out.append(n)
    return out


def strip_struck(text: str) -> str:
    return _STRIKE.sub("", text)


def chunk_note(note: Note, max_tokens: int = MAX_CHUNK_TOKENS) -> list[str]:
    """Chunk by heading, each at most ~max_tokens, prefixed with the title."""
    sections: list[str] = []
    cur: list[str] = []
    for line in strip_struck(note.body).splitlines():
        if re.match(r"#{1,6}\s", line) and cur:
            sections.append("\n".join(cur))
            cur = []
        cur.append(line)
    sections.append("\n".join(cur))
    prefix = f"{note.title}\n"
    limit = max(1, (max_tokens - count_tokens(prefix)) * 4)
    chunks: list[str] = []
    for sec in sections:
        sec = sec.strip()
        if not re.search(r"\w", sec):
            continue
        pieces: list[str] = []
        buf = ""
        for para in re.split(r"\n\s*\n", sec):
            para = para.strip()
            if not para:
                continue
            parts = [para[i : i + limit] for i in range(0, len(para), limit)]
            for part in parts:
                if buf and len(buf) + len(part) + 2 > limit:
                    pieces.append(buf)
                    buf = part
                else:
                    buf = f"{buf}\n\n{part}" if buf else part
        if buf:
            pieces.append(buf)
        chunks.extend(prefix + p for p in pieces)
    return chunks
