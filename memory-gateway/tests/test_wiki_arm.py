import hashlib
import re
import subprocess
from datetime import datetime, timezone
from types import SimpleNamespace

import numpy as np
import pytest

from memory_gateway.arms.base import IngestItem, count_tokens
from memory_gateway.arms.wiki import WikiArm
from memory_gateway.config import Config
from memory_gateway.wiki.notes import Note, chunk_note

DIM = 128


def fake_embed(texts):
    out = []
    for t in texts:
        v = np.zeros(DIM)
        for w in re.findall(r"\w+", t.lower()):
            v[int(hashlib.md5(w.encode()).hexdigest(), 16) % DIM] += 1
        out.append(v.tolist())
    return out


def git(cwd, *args):
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", *args],
        cwd=cwd, check=True, capture_output=True, text=True,
    ).stdout


def note(typ="topic", title="T", tags="[]", extra="", body="Body text.", updated="2026-01-01"):
    return (
        f"---\ntype: {typ}\ntitle: {title}\naliases: []\ntags: {tags}\n"
        f"created: 2026-01-01\nupdated: {updated}\nrelated: []\n{extra}---\n\n{body}\n"
    )


FILES = {
    "INDEX.md": "# Index\nalpha apples\n",
    "moc/nav.md": note(body="alpha apples nav"),
    "topics/apples.md": note(title="Apples", tags="[domain/orchard]", body="# Apples\n\nalpha apples grow on trees.\n\n~~alpha struck gone~~ (old)\n"),
    "topics/pears.md": note(title="Pears", tags="[domain/other]", body="alpha pears are green."),
    "decisions/old.md": note("decision", "Old", extra="status: superseded\n", body="alpha old decision"),
    "decisions/rev.md": note("decision", "Rev", extra="status: reversed\n", body="alpha reversed"),
    "topics/sb.md": note(title="Sb", extra="superseded_by: '[[topics/pears]]'\n", body="alpha sb"),
    "decisions/gone.md": note("decision", "Gone", extra="status: active\n", body="alpha gone decision"),
    "decisions/new.md": note("decision", "New", extra='status: active\nsupersedes: ["[[decisions/gone]]"]\n', body="alpha new decision"),
}


@pytest.fixture
def source(tmp_path):
    src = tmp_path / "src"
    for rel, content in FILES.items():
        p = src / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    git(src, "init", "-q")
    git(src, "add", ".")
    git(src, "commit", "-qm", "init")
    return src


class FakeClient:
    def __init__(self, ops=None, raw=None):
        self.payload = raw if raw is not None else {"ops": ops or []}
        self.calls = []
        self.messages = self

    async def create(self, **kw):
        self.calls.append(kw)
        return SimpleNamespace(content=[SimpleNamespace(type="tool_use", input=self.payload)])


def make(tmp_path, source, client=None, embedder=fake_embed):
    cfg = Config(wiki_source=str(source), state_dir=str(tmp_path / "state"))
    return WikiArm(cfg, tmp_path / "state", embedder=embedder, client=client)


def item(text="remember this", source="session", project="orchard"):
    return IngestItem(project, "s1", source, datetime(2026, 5, 5, tzinfo=timezone.utc), text)


async def test_current_only_and_clone(tmp_path, source):
    arm = make(tmp_path, source)
    await arm.start()
    assert await arm.health() == "ok"
    mems = await arm.recall(None, "alpha", 100000)
    refs = {m.source_ref for m in mems}
    assert refs == {"topics/apples.md", "topics/pears.md", "decisions/new.md"}
    assert all("struck" not in m.text for m in mems)
    assert all(m.text.startswith(("Apples", "Pears", "New")) for m in mems)


def test_chunking_limits():
    n = Note("topics/x.md", {}, "# A\n\n" + "word " * 100 + "\n\n# B\n\n" + "x" * 5000, "", title="X")
    chunks = chunk_note(n)
    assert len(chunks) >= 5
    assert all(count_tokens(c) <= 400 and c.startswith("X\n") for c in chunks)
    assert sum("word" in c for c in chunks) == 1


async def test_budget_and_per_note_cap(tmp_path, source):
    body = "\n\n".join(f"# H{i}\n\nalpha section {i}" for i in range(5))
    (source / "topics/many.md").write_text(note(title="Many", body=body))
    git(source, "add", ".")
    git(source, "commit", "-qm", "m")
    arm = make(tmp_path, source)
    await arm.start()
    mems = await arm.recall(None, "alpha section", 100000)
    assert sum(m.source_ref == "topics/many.md" for m in mems) == 2
    for budget in (10, 25):
        assert sum(m.tokens for m in await arm.recall(None, "alpha", budget)) <= budget


async def test_project_boost(tmp_path, source):
    arm = make(tmp_path, source)
    await arm.start()
    a = await arm.recall("other", "alpha", 100000)
    b = await arm.recall("orchard", "alpha", 100000)
    assert a[0].source_ref == "topics/pears.md"
    assert b[0].source_ref == "topics/apples.md"


async def test_seed_ignored(tmp_path, source):
    client = FakeClient([{"op": "create", "path": "topics/z.md", "body": "x"}])
    arm = make(tmp_path, source, client)
    await arm.start()
    await arm.ingest(item(source="seed"))
    assert client.calls == []


async def test_extractor_ops(tmp_path, source):
    ops = [
        {"op": "create", "path": "decisions/fresh.md", "type": "decision", "title": "Fresh", "body": "zebra stripes"},
        {"op": "create", "path": "../evil.md", "title": "e", "body": "x"},
        {"op": "create", "path": "topics/../../evil.md", "title": "e", "body": "x"},
        {"op": "create", "path": "other/x.md", "title": "e", "body": "x"},
        {"op": "create", "path": "topics/x.txt", "title": "e", "body": "x"},
        {"op": "append", "path": "topics/pears.md", "text": "Pears ripen in autumn."},
        {"op": "supersede", "old_path": "topics/pears.md", "new_path": "decisions/fresh.md", "reason": "r"},
        {"op": "supersede", "old_path": "topics/nope.md", "new_path": "decisions/fresh.md", "reason": "r"},
        "garbage",
    ]
    client = FakeClient(ops)
    arm = make(tmp_path, source, client)
    await arm.start()
    await arm.ingest(item())
    assert client.calls[0]["tools"][0]["input_schema"]
    sh = arm.shadow
    fresh = (sh / "decisions/fresh.md").read_text()
    assert "status: active" in fresh and "2026-05-05" in fresh
    assert "domain/orchard" in fresh and "[[topics/pears]]" in fresh
    pears = (sh / "topics/pears.md").read_text()
    assert "status: superseded" in pears and "Pears ripen" in pears
    assert not (sh.parent / "evil.md").exists() and not (sh / "other").exists()
    assert "ingest s1" in git(sh, "log", "-1", "--format=%s")
    refs = {m.source_ref for m in await arm.recall(None, "zebra stripes alpha", 100000)}
    assert "decisions/fresh.md" in refs and "topics/pears.md" not in refs


@pytest.mark.parametrize("raw", ["junk", {"ops": "x"}, {"nope": 1}])
async def test_malformed_output_makes_no_changes(tmp_path, source, raw):
    arm = make(tmp_path, source, FakeClient(raw=raw))
    await arm.start()
    head = git(arm.shadow, "rev-parse", "HEAD")
    await arm.ingest(item())
    assert git(arm.shadow, "rev-parse", "HEAD") == head


async def test_forget_strikes(tmp_path, source):
    arm = make(tmp_path, source)
    await arm.start()
    ids = await arm.forget(None, "pears are green", "wrong")
    assert ids == ["topics/pears.md#0"]
    path = arm.shadow / "topics/pears.md"
    assert re.search(
        r"~~alpha pears are green\.~~ \(retracted \d{4}-\d\d-\d\d: wrong\)", path.read_text()
    )
    assert all("pears are green" not in m.text for m in await arm.recall(None, "pears green", 10000))


async def test_incremental_reindex(tmp_path, source):
    calls = []

    def counting(texts):
        calls.append(list(texts))
        return fake_embed(texts)

    arm = make(tmp_path, source, embedder=counting)
    await arm.start()
    calls.clear()
    await arm._reindex()
    assert calls == []
    p = arm.shadow / "topics/pears.md"
    p.write_text(p.read_text() + "\nmore pears\n")
    await arm._reindex()
    assert len(calls) == 1 and all("Pears" in t for t in calls[0])


async def test_live_wiki_untouched(tmp_path, source):
    def snapshot():
        return {p: p.read_text() for p in source.rglob("*") if p.is_file() and ".git" not in p.parts}

    head, before = git(source, "rev-parse", "HEAD"), snapshot()
    client = FakeClient([{"op": "append", "path": "topics/pears.md", "text": "extra"}])
    arm = make(tmp_path, source, client)
    await arm.start()
    await arm.ingest(item())
    await arm.forget(None, "apples grow", "r")
    assert git(source, "rev-parse", "HEAD") == head
    assert git(source, "status", "--porcelain") == ""
    assert snapshot() == before
    assert git(arm.shadow, "rev-parse", "HEAD") != head


async def test_forget_strikes_paragraph_in_matched_chunk_under_heading(tmp_path, source):
    body = "# Fruit\nzebra stripes are black.\n\n# Other\nzebra stripes are white."
    (source / "topics/z.md").write_text(note(title="Z", body=body))
    git(source, "add", ".")
    git(source, "commit", "-qm", "z")
    arm = make(tmp_path, source)
    await arm.start()
    ids = await arm.forget(None, "zebra stripes are black", "r")
    text = (arm.shadow / "topics/z.md").read_text()
    assert ids == ["topics/z.md#0"]
    assert "# Fruit\n~~zebra stripes are black.~~ (retracted" in text
    assert "\nzebra stripes are white." in text and "~~zebra stripes are white" not in text
