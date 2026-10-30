import asyncio
import hashlib
import json
import logging
import re
import sqlite3
import subprocess
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Callable

import frontmatter
import numpy as np

from ..config import Config
from ..wiki.notes import chunk_note, current_notes, load_all
from .base import IngestItem, Memory, count_tokens

log = logging.getLogger(__name__)

Embedder = Callable[[list[str]], list[list[float]]]

PROJECT_BOOST = 0.15
MAX_RECENCY = 0.05
PER_NOTE_CAP = 2
NOTE_TYPES = {"decision", "topic", "person", "org", "plan"}
FOLDER_TYPE = {
    "decisions": "decision",
    "topics": "topic",
    "people": "person",
    "orgs": "org",
    "plans": "plan",
}
PATH_RE = re.compile(
    r"^(decisions|topics|people|orgs|plans)/[A-Za-z0-9][A-Za-z0-9_\-]*\.md$"
)

EXTRACT_TOOL = {
    "name": "record_ops",
    "description": "Record durable wiki operations. Empty ops when nothing durable.",
    "input_schema": {
        "type": "object",
        "properties": {
            "ops": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "op": {"enum": ["create", "append", "supersede"]},
                        "path": {"type": "string"},
                        "type": {"type": "string"},
                        "title": {"type": "string"},
                        "body": {"type": "string"},
                        "text": {"type": "string"},
                        "old_path": {"type": "string"},
                        "new_path": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": ["op"],
                },
            }
        },
        "required": ["ops"],
    },
}
EXTRACT_SYSTEM = (
    "You maintain a markdown wiki of durable knowledge (decisions, facts, "
    "preferences). Given new text and related existing notes, call record_ops "
    "with create/append/supersede operations. Paths look like topics/<slug>.md "
    "(folders: decisions, topics, people, orgs, plans). Use supersede when the "
    "new text replaces an existing note. Return empty ops if nothing is durable."
)


class _FastEmbed:
    def __init__(self) -> None:
        self._model: Any = None

    def __call__(self, texts: list[str]) -> list[list[float]]:
        if self._model is None:
            from fastembed import TextEmbedding

            self._model = TextEmbedding("BAAI/bge-small-en-v1.5")
        return [v.tolist() for v in self._model.embed(texts)]


def _parse_date(s: str) -> date | None:
    try:
        return date.fromisoformat(str(s)[:10])
    except ValueError:
        return None


def _git(cwd: Path, *args: str) -> str:
    r = subprocess.run(
        ["git", "-c", "commit.gpgsign=false", "-c", "user.name=memory-gateway",
         "-c", "user.email=memory-gateway@localhost", *args],
        cwd=cwd, capture_output=True, text=True, check=True,
    )
    return r.stdout


def _words(s: str) -> set[str]:
    return set(re.findall(r"\w+", s.lower()))


class WikiArm:
    name = "wiki"

    def __init__(
        self,
        config: Config,
        state_dir: Path,
        embedder: Embedder | None = None,
        client: Any = None,
    ):
        self.config = config
        self.state_dir = Path(state_dir)
        self.shadow = self.state_dir / "wiki"
        self.db_path = self.state_dir / "wiki-index.sqlite"
        self.embedder: Embedder = embedder or _FastEmbed()
        self._client = client
        self._lock = asyncio.Lock()
        self._db: sqlite3.Connection | None = None

    def _connect(self) -> sqlite3.Connection:
        if self._db is None:
            self._db = sqlite3.connect(self.db_path, check_same_thread=False)
            self._db.executescript(
                """
                CREATE TABLE IF NOT EXISTS notes(
                  path TEXT PRIMARY KEY, hash TEXT, updated TEXT, tags TEXT);
                CREATE TABLE IF NOT EXISTS chunks(
                  path TEXT, idx INTEGER, text TEXT, vec BLOB,
                  PRIMARY KEY(path, idx));
                """
            )
        return self._db

    def _clone(self) -> None:
        self.state_dir.mkdir(parents=True, exist_ok=True)
        if not self.shadow.exists():
            subprocess.run(
                ["git", "clone", "--quiet", str(self.config.wiki_path), str(self.shadow)],
                check=True, capture_output=True, text=True,
            )

    @staticmethod
    async def _run(fn, *a):
        return await asyncio.get_running_loop().run_in_executor(None, fn, *a)

    async def start(self) -> None:
        await self._run(self._clone)
        await self._reindex()

    async def health(self) -> str:
        if not (self.shadow / ".git").exists():
            return "error: shadow wiki copy missing"
        if not self.db_path.exists():
            return "error: wiki index missing"
        return "ok"

    async def _embed(self, texts: list[str]) -> np.ndarray:
        return np.asarray(await self._run(self.embedder, texts), dtype=np.float32)

    async def _reindex(self) -> None:
        notes = await self._run(lambda: current_notes(load_all(self.shadow)))
        db = self._connect()
        have = dict(db.execute("SELECT path, hash FROM notes"))
        for p in set(have) - {n.path for n in notes}:
            db.execute("DELETE FROM notes WHERE path=?", (p,))
            db.execute("DELETE FROM chunks WHERE path=?", (p,))
        for n in notes:
            h = hashlib.sha256(n.raw.encode()).hexdigest()
            if have.get(n.path) == h:
                continue
            chunks = chunk_note(n)
            vecs = await self._embed(chunks) if chunks else []
            db.execute("DELETE FROM chunks WHERE path=?", (n.path,))
            for i, (c, v) in enumerate(zip(chunks, vecs)):
                db.execute("INSERT INTO chunks VALUES(?,?,?,?)", (n.path, i, c, v.tobytes()))
            db.execute(
                "INSERT OR REPLACE INTO notes VALUES(?,?,?,?)",
                (n.path, h, n.updated, json.dumps(n.tags)),
            )
        db.commit()

    async def _ranked(self, project: str | None, query: str) -> list[dict]:
        rows = self._connect().execute(
            "SELECT c.path, c.idx, c.text, c.vec, n.updated, n.tags "
            "FROM chunks c JOIN notes n ON n.path=c.path"
        ).fetchall()
        if not rows:
            return []
        q = (await self._embed([query]))[0]
        qn = np.linalg.norm(q) or 1.0
        today = datetime.now(timezone.utc).date()
        out = []
        for path, idx, text, blob, updated, tags in rows:
            v = np.frombuffer(blob, dtype=np.float32)
            score = float(v @ q / ((np.linalg.norm(v) or 1.0) * qn))
            if project and f"domain/{project}" in json.loads(tags):
                score += PROJECT_BOOST
            d = _parse_date(updated)
            if d:
                score += MAX_RECENCY * 0.5 ** (max((today - d).days, 0) / 365)
            out.append(dict(path=path, idx=idx, text=text, updated=updated, score=score))
        out.sort(key=lambda r: -r["score"])
        return out

    async def recall(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        out: list[Memory] = []
        used = 0
        per_note: dict[str, int] = {}
        for r in await self._ranked(project, query):
            if per_note.get(r["path"], 0) >= PER_NOTE_CAP:
                continue
            n = count_tokens(r["text"])
            if used + n > budget_tokens:
                continue
            used += n
            per_note[r["path"]] = per_note.get(r["path"], 0) + 1
            d = _parse_date(r["updated"])
            out.append(
                Memory(
                    id=f"{r['path']}#{r['idx']}",
                    text=r["text"],
                    tokens=n,
                    ts=datetime(d.year, d.month, d.day, tzinfo=timezone.utc) if d else None,
                    arm=self.name,
                    source_ref=r["path"],
                )
            )
            if used >= budget_tokens:
                break
        return out

    def _commit(self, paths: list[str], message: str) -> None:
        _git(self.shadow, "add", "--", *paths)
        if _git(self.shadow, "status", "--porcelain").strip():
            _git(self.shadow, "commit", "-m", message)

    def _safe(self, rel: object) -> Path | None:
        if not isinstance(rel, str) or ".." in rel or not PATH_RE.match(rel):
            return None
        p = (self.shadow / rel).resolve()
        return p if p.is_relative_to(self.shadow.resolve()) else None

    @staticmethod
    def _write(p: Path, post: frontmatter.Post) -> None:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(frontmatter.dumps(post, sort_keys=False) + "\n", encoding="utf-8")

    def _apply_ops(self, ops: list, item: IngestItem) -> list[str]:
        day = item.timestamp.date().isoformat()
        changed: list[str] = []
        for op in ops:
            if not isinstance(op, dict):
                log.warning("wiki: non-dict op ignored")
                continue
            kind = op.get("op")
            try:
                if kind == "create":
                    p = self._safe(op.get("path"))
                    body = op.get("body")
                    if not p or p.exists() or not isinstance(body, str) or not body.strip():
                        raise ValueError("invalid create")
                    rel = op["path"]
                    typ = op.get("type")
                    if typ not in NOTE_TYPES:
                        typ = FOLDER_TYPE[rel.split("/")[0]]
                    meta: dict[str, Any] = {
                        "type": typ,
                        "title": str(op.get("title") or p.stem),
                        "aliases": [],
                        "tags": [f"domain/{item.project}"] if item.project else [],
                        "created": day,
                        "updated": day,
                        "related": [],
                    }
                    if typ == "decision":
                        meta["status"] = "active"
                        meta["supersedes"] = []
                    self._write(p, frontmatter.Post(body.strip(), **meta))
                    changed.append(rel)
                elif kind == "append":
                    p = self._safe(op.get("path"))
                    text = op.get("text")
                    if not p or not p.is_file() or not isinstance(text, str) or not text.strip():
                        raise ValueError("invalid append")
                    post = frontmatter.load(p)
                    post.content = post.content.rstrip() + "\n\n" + text.strip()
                    post["updated"] = day
                    self._write(p, post)
                    changed.append(op["path"])
                elif kind == "supersede":
                    old, new = self._safe(op.get("old_path")), self._safe(op.get("new_path"))
                    if not old or not new or not old.is_file() or not new.is_file() or old == new:
                        raise ValueError("invalid supersede")
                    new_rel = op["new_path"][:-3]
                    reason = str(op.get("reason") or "").strip()
                    post = frontmatter.load(old)
                    post["status"] = "superseded"
                    post["superseded_by"] = f"[[{new_rel}]]"
                    post["updated"] = day
                    post.content = (
                        post.content.rstrip()
                        + f"\n\n**Superseded {day}** by [[{new_rel}]]"
                        + (f": {reason}" if reason else "")
                    )
                    self._write(old, post)
                    changed.append(op["old_path"])
                    npost = frontmatter.load(new)
                    if npost.get("type") == "decision" or "supersedes" in npost.metadata:
                        cur = list(npost.get("supersedes") or [])
                        link = f"[[{op['old_path'][:-3]}]]"
                        if link not in cur:
                            cur.append(link)
                        npost["supersedes"] = cur
                        self._write(new, npost)
                        changed.append(op["new_path"])
                else:
                    raise ValueError(f"unknown op {kind!r}")
            except (ValueError, OSError) as e:
                log.warning("wiki: rejected op %r: %s", op, e)
        return list(dict.fromkeys(changed))

    async def _extract(self, item: IngestItem, related: list[Memory]) -> list:
        if self._client is None:
            import anthropic

            self._client = anthropic.AsyncAnthropicBedrock(
                aws_region=self.config.aws_region
            )
        ctx = "\n\n".join(f"[{m.source_ref}]\n{m.text}" for m in related)
        prompt = (
            f"Project: {item.project or 'none'}\nDate: {item.timestamp.date()}\n\n"
            f"Related existing notes:\n{ctx or '(none)'}\n\nNew text:\n{item.text}"
        )
        # Model output is untrusted; any failure means "no ops", never a crash.
        try:
            resp = await self._client.messages.create(
                model=self.config.bedrock_model,
                max_tokens=4096,
                system=EXTRACT_SYSTEM,
                tools=[EXTRACT_TOOL],
                tool_choice={"type": "tool", "name": "record_ops"},
                messages=[{"role": "user", "content": prompt}],
            )
            for block in resp.content:
                if getattr(block, "type", None) == "tool_use":
                    data = block.input
                    if isinstance(data, str):
                        data = json.loads(data)
                    ops = data.get("ops") if isinstance(data, dict) else None
                    return ops if isinstance(ops, list) else []
        except Exception as e:
            log.warning("wiki: extractor failed: %s", e)
        return []

    async def ingest(self, item: IngestItem) -> None:
        if item.source not in ("session", "retain"):
            return
        async with self._lock:
            related = (await self.recall(item.project, item.text[:2000], 10**6))[:5]
            ops = await self._extract(item, related)
            changed = await self._run(self._apply_ops, ops, item) if ops else []
            if changed:
                await self._run(
                    self._commit, changed, f"memory-gateway: ingest {item.session_id}"
                )
                await self._reindex()

    async def forget(self, project: str | None, text: str, reason: str) -> list[str]:
        async with self._lock:
            ranked = await self._ranked(project, text)
            if not ranked:
                return []
            best = ranked[0]
            rel = best["path"]
            if not await self._run(self._strike, rel, best["text"], text, reason):
                return []
            await self._run(self._commit, [rel], f"memory-gateway: retract in {rel}")
            await self._reindex()
            return [f"{rel}#{best['idx']}"]

    def _strike(self, rel: str, chunk: str, query: str, reason: str) -> bool:
        p = self.shadow / rel
        post = frontmatter.load(p)
        paras = re.split(r"(\n\s*\n)", post.content)
        target = _words(query)
        best, best_score = -1, 0.0
        for i in range(0, len(paras), 2):
            lines = paras[i].strip().splitlines()
            while lines and re.match(r"#{1,6}\s", lines[0]):
                lines.pop(0)  # heading lines stay outside the strike
            stripped = "\n".join(lines).strip()
            if not stripped or stripped.startswith("~~") or stripped not in chunk:
                continue
            w = _words(stripped)
            score = len(w & target) / (len(w | target) or 1)
            if score > best_score:
                best, best_score = i, score
        if best < 0:
            return False
        para = paras[best]
        lines = para.strip().splitlines()
        n_head = 0
        while n_head < len(lines) and re.match(r"#{1,6}\s", lines[n_head]):
            n_head += 1
        head = "".join(line + "\n" for line in lines[:n_head])
        body = "\n".join(lines[n_head:]).strip()
        lead = para[: len(para) - len(para.lstrip())]
        paras[best] = (
            f"{lead}{head}~~{body}~~ (retracted {date.today().isoformat()}: {reason})"
        )
        post.content = "".join(paras)
        self._write(p, post)
        return True
