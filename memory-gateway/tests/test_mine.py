import json
import stat

import pytest

from memory_gateway.eval import mine
from tests.test_seed import _commit, init_repo


@pytest.fixture(autouse=True)
def eval_env(tmp_path, monkeypatch):
    monkeypatch.setenv("MEMORY_GATEWAY_EVAL_DIR", str(tmp_path / "eval"))
    return tmp_path / "eval"


def _read(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def test_supersession_candidates(tmp_path, eval_env):
    r = init_repo(tmp_path / "wiki")
    _commit(r, {
        "decisions/old.md": "---\nstatus: superseded\n---\nuse tool A\n",
        "decisions/new.md": "---\nstatus: accepted\nsupersedes: [old]\n---\nuse tool B\n",
        "notes/x.md": "---\ntitle: x\n---\nSuperseded: ~~port 80~~ now port 81\n",
        "notes/y.md": "---\ntitle: y\n---\nline keep\ncolor red\n",
    }, "2024-01-01T00:00:00+00:00")
    _commit(r, {"notes/y.md": "---\ntitle: z\n---\nline keep\ncolor blue\n"}, "2024-02-01T00:00:00+00:00")
    mine.main(["supersession-candidates", "--wiki", str(r)])
    rows = _read(eval_env / "supersession-candidates.jsonl")
    assert all(set(x) == {"id", "source", "path", "stale_text", "current_text", "current_ref", "date"} for x in rows)
    a = next(x for x in rows if x["path"] == "decisions/old.md")
    assert "tool A" in a["stale_text"] and "tool B" in a["current_text"] and a["current_ref"] == "decisions/new.md"
    b = next(x for x in rows if x["stale_text"] == "port 80")
    assert "now port 81" in b["current_text"]
    c = next(x for x in rows if x["path"] == "notes/y.md")
    assert c["stale_text"] == "color red" and c["current_text"] == "color blue"
    assert stat.S_IMODE(eval_env.stat().st_mode) == 0o700


def _msg(i, role, content):
    return {"type": "message", "id": i, "timestamp": "2025-01-01T00:00:00Z", "message": {"role": role, "content": content}}


def _call(i, path):
    return {"type": "toolCall", "id": i, "name": "read", "arguments": {"path": path}}


def _sessions(tmp_path, wiki):
    s = tmp_path / "sessions"
    d = s / "--proj--"
    d.mkdir(parents=True)
    sub = s / "--x-subagent-worktrees-1--"
    sub.mkdir()
    lines = [
        {"type": "session", "id": "s"},
        _msg("u1", "user", [{"type": "text", "text": "hello there"}]),
        _msg("a1", "assistant", [{"type": "text", "text": "we use A"},
                                 _call("t", str(wiki / "topics/b.md")),
                                 _call("t2", str(wiki / "INDEX.md")),
                                 _call("t3", "/etc/hosts")]),
        _msg("u2", "user", [{"type": "text", "text": "Actually, we switched to B"}]),
        _msg("a2", "assistant", [_call("t4", str(wiki / "c.md"))]),
    ]
    (d / "a.jsonl").write_text("\n".join(json.dumps(x) for x in lines) + "\nnot json\n")
    (sub / "b.jsonl").write_text(json.dumps(_msg("u9", "user", "no longer x")) + "\n")
    return s


def test_transcript_candidates(tmp_path, eval_env):
    s = _sessions(tmp_path, tmp_path / "w")
    mine.main(["transcript-candidates", "--sessions", str(s)])
    rows = _read(eval_env / "transcript-candidates.jsonl")
    assert len(rows) == 1
    assert rows[0]["entry_id"] == "u2" and rows[0]["preceding_assistant_text"] == "we use A"
    assert rows[0]["source"] == "transcript" and rows[0]["user_text"].startswith("Actually")


def test_transcript_cap(tmp_path, eval_env):
    d = tmp_path / "s" / "p"
    d.mkdir(parents=True)
    (d / "a.jsonl").write_text("\n".join(json.dumps(_msg(f"u{i}", "user", "deprecated")) for i in range(400)))
    assert len(mine.transcript_candidates(tmp_path / "s")) == 300


def test_wiki_read_labels(tmp_path, eval_env):
    w = tmp_path / "w"
    s = _sessions(tmp_path, w)
    mine.main(["wiki-read-labels", "--sessions", str(s), "--wiki", str(w)])
    rows = _read(eval_env / "wiki-read-labels.jsonl")
    assert [(r["turn_index"], r["reads"]) for r in rows] == [(0, ["topics/b.md"]), (1, ["c.md"])]
    assert rows[1]["prompt"].startswith("Actually") and rows[0]["session_file"].endswith("a.jsonl")


def test_supersession_survives_bad_frontmatter_and_non_ascii(tmp_path, eval_env):
    r = init_repo(tmp_path / "wiki")
    _commit(r, {"bad.md": "---\na: [unclosed\n---\nbody\n", "caf\u00e9.md": "v1 line\n"}, "2024-01-01T00:00:00+00:00")
    _commit(r, {"bad.md": "---\na: [unclosed\n---\nbody2\n", "caf\u00e9.md": "v2 line\n"}, "2024-02-01T00:00:00+00:00")
    rows = mine.supersession_candidates(r)
    assert [x["stale_text"] for x in rows] == ["v1 line"]
