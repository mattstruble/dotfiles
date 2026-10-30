import json
import os
import sqlite3
import stat
import subprocess

import httpx
import pytest
import respx

from memory_gateway import seed

GW = "http://gw.test"
SAMPLE_BD = """Memories (2):

  first-key
    first content

  second-key
    second content line one
    continued
"""


@pytest.fixture(autouse=True)
def eval_env(tmp_path, monkeypatch):
    monkeypatch.setenv("MEMORY_GATEWAY_EVAL_DIR", str(tmp_path / "eval"))
    return tmp_path / "eval"


def _commit(repo, files, date, msg="c", delete=()):
    for p, t in files.items():
        f = repo / p
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(t)
    for p in delete:
        (repo / p).unlink()
    env = {**os.environ, "GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date}
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True, env=env)
    subprocess.run(["git", "-C", str(repo), "-c", "commit.gpgsign=false", "commit", "-qm", msg], check=True, env=env)


def init_repo(path):
    path.mkdir()
    subprocess.run(["git", "-C", str(path), "init", "-q"], check=True)
    subprocess.run(["git", "-C", str(path), "config", "user.email", "t@t"], check=True)
    subprocess.run(["git", "-C", str(path), "config", "user.name", "t"], check=True)
    return path


@pytest.fixture
def wiki(tmp_path):
    r = init_repo(tmp_path / "wiki")
    _commit(r, {"a.md": "a v1", "INDEX.md": "idx", "moc/m.md": "moc", "attachments/x.md": "att", "n.txt": "t"}, "2023-01-01T00:00:00+00:00")
    _commit(r, {"a.md": "a v2", "topics/b.md": "b v1"}, "2024-02-01T00:00:00+00:00")
    _commit(r, {"c.md": "c"}, "2024-03-01T00:00:00+00:00")
    _commit(r, {}, "2024-04-01T00:00:00+00:00", delete=["c.md"])
    return r


@respx.mock
def test_replay_order_payload_and_skips(wiki):
    route = respx.post(f"{GW}/ingest").mock(return_value=httpx.Response(202, json={}))
    seed.run(GW, wiki, [], None, None, False)
    bodies = [json.loads(c.request.content) for c in route.calls]
    assert [(b["doc_id"], b["text"]) for b in bodies] == [
        ("wiki:a.md", "a v1"), ("wiki:a.md", "a v2"), ("wiki:topics/b.md", "b v1"), ("wiki:c.md", "c")]
    b = bodies[0]
    assert b["project"] is None and b["session_id"] == "seed" and b["source"] == "seed"
    assert b["timestamp"].startswith("2023-01-01")


@respx.mock
def test_resume_is_idempotent(wiki):
    route = respx.post(f"{GW}/ingest").mock(return_value=httpx.Response(202, json={}))
    assert seed.run(GW, wiki, [], None, 2, False)["sent"] == 2
    assert seed.run(GW, wiki, [], None, None, False) == {"sent": 2, "skipped": 2}
    assert seed.run(GW, wiki, [], None, None, False) == {"sent": 0, "skipped": 4}
    assert route.call_count == 4


@respx.mock
def test_dry_run_sends_nothing(wiki, capsys):
    route = respx.post(f"{GW}/ingest").mock(return_value=httpx.Response(202))
    res = seed.run(GW, wiki, [], None, None, True)
    out = capsys.readouterr().out
    assert route.call_count == 0
    assert res["count"] == 4 and "2023: 1" in out and "2024: 3" in out and "total: 4" in out


def test_parse_bd_memories():
    assert seed.parse_bd_memories(SAMPLE_BD) == [
        ("first-key", "first content"), ("second-key", "second content line one continued")]


def test_bd_items_project_and_doc_id(tmp_path, monkeypatch):
    repo = tmp_path / "MyRepo"
    repo.mkdir()
    monkeypatch.setattr(seed.subprocess, "run", lambda *a, **k: subprocess.CompletedProcess(a, 0, SAMPLE_BD, ""))
    items = list(seed.bd_items(repo))
    assert [i[:3] for i in items] == [("myrepo", "bd:myrepo:first-key", "bd"), ("myrepo", "bd:myrepo:second-key", "bd")]


def test_eval_dir_mode(eval_env):
    seed._progress_db().close()
    assert stat.S_IMODE(eval_env.stat().st_mode) == 0o700


@respx.mock
def test_non_ascii_path_and_invalid_utf8(tmp_path):
    r = init_repo(tmp_path / "w2")
    _commit(r, {"caf\u00e9.md": "ok"}, "2024-01-01T00:00:00+00:00")
    (r / "bin.md").write_bytes(b"bad \xff byte")
    _commit(r, {}, "2024-02-01T00:00:00+00:00")
    route = respx.post(f"{GW}/ingest").mock(return_value=httpx.Response(202, json={}))
    seed.run(GW, r, [], None, None, False)
    assert [json.loads(c.request.content)["doc_id"] for c in route.calls] == ["wiki:caf\u00e9.md", "wiki:bin.md"]


@respx.mock
def test_arms_subset_forwarded_and_resume_is_arm_aware(wiki):
    route = respx.post(f"{GW}/ingest").mock(return_value=httpx.Response(202, json={}))
    assert seed.run(GW, wiki, [], None, None, False, ["hindsight"])["sent"] == 4
    assert all(json.loads(c.request.content)["arms"] == ["hindsight"] for c in route.calls)
    assert seed.run(GW, wiki, [], None, None, False, ["hindsight"])["sent"] == 0
    # other arm set and default are not skipped
    assert seed.run(GW, wiki, [], None, None, False, ["graphiti"])["sent"] == 4
    assert seed.run(GW, wiki, [], None, None, False)["sent"] == 4
    assert "arms" not in json.loads(route.calls.last.request.content)
    assert seed.run(GW, wiki, [], None, None, False)["sent"] == 0


def test_progress_db_migrates_legacy_rows_as_all(eval_env):
    eval_env.mkdir(parents=True, exist_ok=True)
    old = sqlite3.connect(eval_env / "seed-progress.sqlite")
    old.execute("CREATE TABLE sent (doc_id TEXT, commit_ref TEXT, PRIMARY KEY (doc_id, commit_ref))")
    old.execute("INSERT INTO sent VALUES ('d', 'c')")
    old.commit()
    old.close()
    db = seed._progress_db()
    assert db.execute("SELECT doc_id, commit_ref, arms FROM sent").fetchall() == [("d", "c", "all")]
