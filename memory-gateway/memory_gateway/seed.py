"""Seed the gateway from wiki git history and `bd memories`.

Usage: python -m memory_gateway.seed [--gateway URL] [--wiki PATH]
       [--beads-repo PATH ...] [--arms a[,b]] [--since DATE] [--limit N] [--dry-run]
"""
import argparse
import re
import sqlite3
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

import httpx

from .eval import eval_dir

_HEADER = re.compile(r"^([0-9a-f]{40})\t(\S+)$")


def _git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), "-c", "core.quotepath=false", *args],
        check=True, capture_output=True, text=True, encoding="utf-8", errors="replace",
    ).stdout


def wanted(path: str) -> bool:
    if not path.endswith(".md"):
        return False
    return not (path == "INDEX.md" or path.startswith(("moc/", "attachments/")))


def iter_commits(repo: Path, since: str | None = None):
    """Yield (hash, iso_date, [(status, path)]) oldest first; status is A/M/D."""
    args = ["log", "--reverse", "--format=%H%x09%cI", "--name-status"]
    if since:
        args.append(f"--since={since}")
    cur = None
    for line in _git(repo, *args).splitlines():
        m = _HEADER.match(line)
        if m:
            if cur:
                yield cur
            cur = (m.group(1), m.group(2), [])
        elif line.strip() and cur:
            parts = line.split("\t")
            st = parts[0][0]
            if st == "R":  # rename: old deleted, new added
                cur[2].append(("D", parts[1]))
                cur[2].append(("A", parts[2]))
            elif st == "C":
                cur[2].append(("A", parts[2]))
            else:
                cur[2].append((st, parts[1]))
    if cur:
        yield cur


def wiki_items(repo: Path, since: str | None = None):
    """Yield (doc_id, commit, timestamp, text) for each added/modified note version."""
    for h, date, changes in iter_commits(repo, since):
        for st, path in changes:
            if st not in ("A", "M") or not wanted(path):
                continue
            try:
                text = _git(repo, "show", f"{h}:{path}")
            except subprocess.CalledProcessError:
                continue
            yield f"wiki:{path}", h, date, text


def parse_bd_memories(out: str) -> list[tuple[str, str]]:
    """Parse `bd memories` output: 2-space-indented key, 4-space-indented content."""
    mems: list[tuple[str, list[str]]] = []
    for line in out.splitlines():
        if re.match(r"^ {4}\S", line) and mems:
            mems[-1][1].append(line.strip())
        elif re.match(r"^ {2}\S", line):
            mems.append((line.strip(), []))
    return [(k, " ".join(c)) for k, c in mems if c]


def bd_items(repo: Path):
    out = subprocess.run(
        ["bd", "memories"], cwd=repo, check=True, capture_output=True, text=True
    ).stdout
    name = repo.resolve().name.lower()
    now = datetime.now(timezone.utc).isoformat()
    for key, content in parse_bd_memories(out):
        yield name, f"bd:{name}:{key}", "bd", now, content


def _progress_db() -> sqlite3.Connection:
    db = sqlite3.connect(eval_dir() / "seed-progress.sqlite")
    cols = [r[1] for r in db.execute("PRAGMA table_info(sent)")]
    if cols and "arms" not in cols:  # migrate: legacy rows were sent to all arms
        db.execute("ALTER TABLE sent RENAME TO sent_old")
        db.execute("CREATE TABLE sent (doc_id TEXT, commit_ref TEXT, arms TEXT NOT NULL, PRIMARY KEY (doc_id, commit_ref, arms))")
        db.execute("INSERT INTO sent SELECT doc_id, commit_ref, 'all' FROM sent_old")
        db.execute("DROP TABLE sent_old")
        db.commit()
    db.execute("CREATE TABLE IF NOT EXISTS sent (doc_id TEXT, commit_ref TEXT, arms TEXT NOT NULL, PRIMARY KEY (doc_id, commit_ref, arms))")
    return db


def run(gateway: str, wiki: Path, beads: list[Path], since: str | None, limit: int | None, dry_run: bool,
        arms: list[str] | None = None) -> dict:
    items = [(None, d, c, ts, t) for d, c, ts, t in wiki_items(wiki, since)]
    for repo in beads:
        items.extend(bd_items(repo))
    if dry_run:
        years: Counter = Counter()
        chars = 0
        for _, _, _, ts, t in items:
            years[ts[:4]] += 1
            chars += len(t)
        for y in sorted(years):
            print(f"{y}: {years[y]}")
        print(f"total: {len(items)} items, {chars} chars")
        return {"count": len(items), "chars": chars}
    db = _progress_db()
    arms_key = ",".join(sorted(set(arms))) if arms else "all"
    sent = skipped = 0
    with httpx.Client(base_url=gateway, timeout=30) as client:
        for project, doc_id, commit, ts, text in items:
            if limit is not None and sent >= limit:
                break
            if db.execute("SELECT 1 FROM sent WHERE doc_id=? AND commit_ref=? AND arms=?", (doc_id, commit, arms_key)).fetchone():
                skipped += 1
                continue
            body = {
                "project": project, "session_id": "seed", "source": "seed",
                "timestamp": ts, "text": text, "doc_id": doc_id,
            }
            if arms:
                body["arms"] = sorted(set(arms))
            r = client.post("/ingest", json=body)
            r.raise_for_status()
            db.execute("INSERT INTO sent VALUES (?, ?, ?)", (doc_id, commit, arms_key))
            db.commit()
            sent += 1
    print(f"sent {sent}, skipped {skipped}")
    return {"sent": sent, "skipped": skipped}


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(prog="memory_gateway.seed")
    p.add_argument("--gateway", default="http://127.0.0.1:8010")
    p.add_argument("--wiki", default="~/llm-wiki")
    p.add_argument("--beads-repo", action="append", default=[])
    p.add_argument("--arms", help="comma-separated arm subset forwarded to /ingest")
    p.add_argument("--since")
    p.add_argument("--limit", type=int)
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args(argv)
    run(a.gateway, Path(a.wiki).expanduser(), [Path(b).expanduser() for b in a.beads_repo],
        a.since, a.limit, a.dry_run,
        [x for x in a.arms.split(",") if x] if a.arms else None)


if __name__ == "__main__":
    main()
