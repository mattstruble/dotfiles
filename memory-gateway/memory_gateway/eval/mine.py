"""Mine eval candidates/labels into the eval dir (never the repo).

Usage: python -m memory_gateway.eval.mine {supersession-candidates|transcript-candidates|wiki-read-labels}
"""
import argparse
import difflib
import json
import re
import subprocess
from pathlib import Path

import frontmatter
import yaml

from . import eval_dir
from ..seed import _git, iter_commits, wanted

IMPLICIT = re.compile(
    r"switched to|instead of|no longer|replaced|we now|from now on|actually,|not anymore|deprecated",
    re.I,
)
STRIKE = re.compile(r"~~(.+?)~~")
CAP_SUPERSESSION = 200
CAP_TRANSCRIPT = 300


def _write(name: str, rows: list[dict]) -> Path:
    out = eval_dir() / name
    with out.open("w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    return out


def _aslist(v) -> list[str]:
    if v is None:
        return []
    return [str(x) for x in v] if isinstance(v, list) else [str(v)]


def _ref_matches(ref: str, path: str) -> bool:
    ref = ref.strip().strip("[]").split("|")[0].removesuffix(".md")
    p = path.removesuffix(".md")
    return ref == p or ref == Path(p).name or p.endswith("/" + ref)


def supersession_candidates(wiki: Path) -> list[dict]:
    rows: list[dict] = []
    notes: dict[str, frontmatter.Post] = {}
    for f in sorted(wiki.rglob("*.md")):
        rel = f.relative_to(wiki).as_posix()
        if rel.startswith(".") or not wanted(rel):
            continue
        try:
            notes[rel] = frontmatter.loads(f.read_text())
        except (OSError, ValueError, yaml.YAMLError):
            continue

    def date_of(post) -> str:
        return str(post.get("date") or post.get("updated") or "")

    # A: status superseded <-> supersedes
    for cur_path, cur in notes.items():
        for ref in _aslist(cur.get("supersedes")):
            for old_path, old in notes.items():
                if old.get("status") == "superseded" and _ref_matches(ref, old_path):
                    rows.append({"source": "wiki", "path": old_path, "stale_text": old.content,
                                 "current_text": cur.content, "current_ref": cur_path,
                                 "date": date_of(cur)})
    # B: struck text near superseded markers
    for path, post in notes.items():
        if "superseded" not in post.content.lower():
            continue
        lines = post.content.splitlines()
        for i, line in enumerate(lines):
            for m in STRIKE.finditer(line):
                cur = STRIKE.sub("", line).strip() or " ".join(lines[i + 1:i + 3]).strip()
                rows.append({"source": "wiki", "path": path, "stale_text": m.group(1),
                             "current_text": cur, "current_ref": path, "date": date_of(post)})
    # C: body changes across git history
    prev: dict[str, str] = {}
    for h, date, changes in iter_commits(wiki):
        for st, path in changes:
            if not wanted(path):
                continue
            if st == "D":
                prev.pop(path, None)
                continue
            try:
                body = frontmatter.loads(_git(wiki, "show", f"{h}:{path}")).content
            except (subprocess.CalledProcessError, ValueError, yaml.YAMLError):
                continue
            old = prev.get(path)
            prev[path] = body
            if st != "M" or old is None:
                continue
            a, b = old.splitlines(), body.splitlines()
            for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
                if op == "replace":
                    rows.append({"source": "wiki", "path": path,
                                 "stale_text": "\n".join(a[i1:i2])[:1000],
                                 "current_text": "\n".join(b[j1:j2])[:1000],
                                 "current_ref": f"{path}@{h[:12]}", "date": date})
    rows = rows[:CAP_SUPERSESSION]
    keys = ("id", "source", "path", "stale_text", "current_text", "current_ref", "date")
    return [{k: v for k, v in {**r, "id": f"sup-{n:04d}"}.items() if k in keys} for n, r in enumerate(rows)]


def _blocks_text(content) -> str:
    if isinstance(content, str):
        return content
    return "\n".join(b.get("text", "") for b in content or [] if isinstance(b, dict) and b.get("type") == "text")


def session_files(sessions: Path) -> list[Path]:
    return sorted(f for d in sessions.iterdir() if d.is_dir() and "subagent-worktrees" not in d.name
                  for f in d.glob("*.jsonl"))


def _entries(f: Path):
    with f.open() as fh:
        for line in fh:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def transcript_candidates(sessions: Path) -> list[dict]:
    rows: list[dict] = []
    for f in session_files(sessions):
        last_asst = ""
        for e in _entries(f):
            if e.get("type") != "message":
                continue
            msg = e.get("message") or {}
            text = _blocks_text(msg.get("content"))
            if msg.get("role") == "assistant":
                last_asst = text
            elif msg.get("role") == "user" and IMPLICIT.search(text):
                rows.append({"id": f"tr-{len(rows):04d}", "source": "transcript",
                             "session_file": str(f), "entry_id": e.get("id"),
                             "timestamp": e.get("timestamp"), "user_text": text[:600],
                             "preceding_assistant_text": last_asst[:600]})
                if len(rows) >= CAP_TRANSCRIPT:
                    return rows
    return rows


def wiki_read_labels(sessions: Path, wiki: Path) -> list[dict]:
    wiki = wiki.expanduser().resolve()
    rows: list[dict] = []
    for f in session_files(sessions):
        turn = -1
        cur: dict | None = None
        for e in _entries(f):
            if e.get("type") != "message":
                continue
            msg = e.get("message") or {}
            if msg.get("role") == "user":
                turn += 1
                cur = {"session_file": str(f), "turn_index": turn,
                       "prompt": _blocks_text(msg.get("content"))[:1000],
                       "timestamp": e.get("timestamp"), "reads": []}
                rows.append(cur)
            elif msg.get("role") == "assistant" and cur is not None:
                for b in msg.get("content") or []:
                    if not (isinstance(b, dict) and b.get("type") == "toolCall" and b.get("name") == "read"):
                        continue
                    p = (b.get("arguments") or {}).get("path")
                    if not isinstance(p, str):
                        continue
                    rp = Path(p).expanduser().resolve()
                    if rp.is_relative_to(wiki) and rp.name != "INDEX.md":
                        rel = rp.relative_to(wiki).as_posix()
                        if rel not in cur["reads"]:
                            cur["reads"].append(rel)
    return rows


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(prog="memory_gateway.eval.mine")
    p.add_argument("command", choices=["supersession-candidates", "transcript-candidates", "wiki-read-labels"])
    p.add_argument("--wiki", default="~/llm-wiki")
    p.add_argument("--sessions", default="~/.pi/agent/sessions")
    a = p.parse_args(argv)
    wiki = Path(a.wiki).expanduser()
    sessions = Path(a.sessions).expanduser()
    if a.command == "supersession-candidates":
        rows, name = supersession_candidates(wiki), "supersession-candidates.jsonl"
    elif a.command == "transcript-candidates":
        rows, name = transcript_candidates(sessions), "transcript-candidates.jsonl"
    else:
        rows, name = wiki_read_labels(sessions, wiki), "wiki-read-labels.jsonl"
    print(f"wrote {len(rows)} rows to {_write(name, rows)}")


if __name__ == "__main__":
    main()
