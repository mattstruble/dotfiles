"""Rows for the wiki history index: non-current text of a note."""

import re
import subprocess
from pathlib import Path

from .notes import Note, chunk_note, parse_post

PREVIOUS_VERSIONS = 3
_STRUCK = re.compile(r"~~(.+?)~~", re.DOTALL)


def _paras(text: str) -> list[str]:
    return [p.strip() for p in re.split(r"\n\s*\n", text) if re.search(r"\w", p)]


def _norm(p: str) -> str:
    return " ".join(p.split())


def _git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True, check=True
    ).stdout


def history_rows(
    root: Path, note: Note, is_current: bool
) -> list[tuple[str, str, int, str]]:
    """Return (commit, commit_date, n, text) rows; n numbers rows per commit."""
    try:
        log = [
            line.split(" ", 1)
            for line in _git(
                root, "log", "--format=%H %cI", "-n", str(PREVIOUS_VERSIONS + 1),
                "--", note.path,
            ).splitlines()
        ]
    except subprocess.CalledProcessError:
        return []
    if not log:
        return []
    head_commit, head_date = log[0]
    if is_current:
        texts = [_norm(m) for m in _STRUCK.findall(note.body)]
    else:
        texts = [c[len(note.title) + 1 :] for c in chunk_note(note)]
    rows = [(head_commit, head_date, i, t) for i, t in enumerate(texts) if t.strip()]

    current = {_norm(p) for p in _paras(note.body)}
    for commit, date in log[1:]:
        try:
            raw = _git(root, "show", f"{commit}:{note.path}")
        except subprocess.CalledProcessError:
            continue
        n = 0
        for p in _paras(parse_post(raw, note.path).content):
            if _norm(p) in current:
                continue
            rows.append((commit, date, n, p))
            n += 1
    return rows
