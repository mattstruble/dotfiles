import asyncio
import json
from datetime import datetime, timezone

import httpx

from memory_gateway import arms
from memory_gateway.arms.base import Memory, SourceRecord
from memory_gateway.app import create_app
from memory_gateway.config import Config, ensure_state_dir
from memory_gateway.gateway import Gateway
from memory_gateway.queue import DurableQueue

from .conftest import FakeArm, make_item


async def wait_for(pred, timeout=5.0):
    end = asyncio.get_running_loop().time() + timeout
    while not pred():
        assert asyncio.get_running_loop().time() < end, "timed out"
        await asyncio.sleep(0.02)


def gw(config, tmp_path, arm_map):
    return Gateway(config, tmp_path, arms=arm_map, poll_interval_s=0.02, backoff_base_s=0.05)


async def test_fanout_preserves_enqueue_order(config, tmp_path):
    a, b = FakeArm("a"), FakeArm("b")
    g = gw(config, tmp_path, {"a": a, "b": b})
    await g.startup()
    for i in range(5):
        g.ingest(make_item(f"t{i}"))
    await wait_for(lambda: len(a.ingested) == 5 and len(b.ingested) == 5)
    assert [i.text for i in a.ingested] == [f"t{i}" for i in range(5)]
    await wait_for(lambda: g.queue.depth() == 0)
    await g.shutdown()


async def test_failing_arm_retries_without_blocking_other_arm_or_reordering(config, tmp_path):
    a, b = FakeArm("a", fail_ingest=3), FakeArm("b")
    g = gw(config, tmp_path, {"a": a, "b": b})
    await g.startup()
    g.ingest(make_item("one"))
    g.ingest(make_item("two"))
    await wait_for(lambda: len(b.ingested) == 2)
    await wait_for(lambda: [i.text for i in a.ingested] == ["one", "two"])
    await g.shutdown()


async def test_undelivered_items_survive_restart(config, tmp_path):
    g1 = gw(config, tmp_path, {"a": FakeArm("a")})  # workers never started
    g1.ingest(make_item("persisted"))
    g1.queue.close()

    a2 = FakeArm("a")
    g2 = gw(config, tmp_path, {"a": a2})
    assert g2.queue.depth() == 1
    await g2.startup()
    await wait_for(lambda: [i.text for i in a2.ingested] == ["persisted"])
    await g2.shutdown()


async def test_hung_ingest_times_out_and_retries(config, tmp_path):
    class HangOnce(FakeArm):
        async def ingest(self, item):
            if not getattr(self, "hung", False):
                self.hung = True
                await asyncio.sleep(60)
            await super().ingest(item)

    config.ingest_timeout_s = 0.1
    a = HangOnce("a")
    g = gw(config, tmp_path, {"a": a})
    await g.startup()
    g.ingest(make_item("x"))
    await wait_for(lambda: len(a.ingested) == 1)
    await g.shutdown()


async def test_worker_survives_queue_errors(config, tmp_path):
    a = FakeArm("a")
    g = gw(config, tmp_path, {"a": a})
    real = g.queue.next_for
    calls = {"n": 0}

    def flaky(arm):
        calls["n"] += 1
        if calls["n"] == 1:
            raise RuntimeError("database is locked")
        return real(arm)

    g.queue.next_for = flaky
    await g.startup()
    g.ingest(make_item("x"))
    await wait_for(lambda: len(a.ingested) == 1)
    await g.shutdown()


def test_delivery_abandoned_after_24h(tmp_path):
    q = DurableQueue(tmp_path / "q.sqlite")
    q.enqueue(make_item(), ["a"])
    q._db.execute("UPDATE items SET created = created - 90000")
    q.mark_failed_attempt(1, "a", "boom")
    assert (q.depth(), q.failed()) == (0, 1)


async def test_recall_enforces_budget_reports_timeouts_and_logs(config, tmp_path):
    g = gw(config, tmp_path, {"a": FakeArm("a"), "slow": FakeArm("slow", recall_delay=2)})

    out = await g.recall("p", "q", 14, None)  # each memory is 12 tokens
    assert [m.id for m in out["results"]["a"]] == ["a-0"]
    assert "timeout" in out["errors"]["slow"]

    out = await g.recall(None, "q", 100, ["a", "nope"])
    assert len(out["results"]["a"]) == 3
    assert out["errors"]["nope"] == "unknown arm"

    lines = [json.loads(x) for x in (tmp_path / "recall-log.jsonl").read_text().splitlines()]
    assert len(lines) == 2
    assert lines[0]["request"]["query"] == "q"
    assert lines[0]["arms"]["a"]["memories"][0]["tokens"] == 12
    assert lines[0]["arms"]["slow"]["error"]
    g.queue.close()


async def test_http_api_roundtrip(config, tmp_path):
    a = FakeArm("a")
    app = create_app(gw(config, tmp_path, {"a": a}))
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
            assert (await c.get("/health")).json()["arms"] == {"a": "ok"}

            r = await c.post(
                "/ingest",
                json={"project": "p", "session_id": "s", "source": "seed",
                      "timestamp": "2025-01-01T00:00:00Z", "text": "x"},
            )
            assert r.status_code == 202 and r.json()["queued"] is True
            await wait_for(lambda: len(a.ingested) == 1)

            r = await c.post("/recall", json={"project": "p", "query": "q", "budget_tokens": 100})
            assert len(r.json()["results"]["a"]) == 3 and r.json()["errors"] == {}

            r = await c.post("/forget", json={"project": "p", "text": "t", "reason": "r"})
            assert r.json() == {"arms": {"a": ["a-0"]}}


async def test_arm_with_missing_module_is_unhealthy_not_fatal(config, tmp_path, monkeypatch):
    monkeypatch.setitem(arms.REGISTRY, "ghost", "memory_gateway.arms.ghost:GhostArm")
    config.arms = ["ghost"]
    g = Gateway(config, tmp_path)

    h = await g.health()

    assert h["ok"] is True
    assert h["arms"]["ghost"].startswith("error:")
    await g.shutdown()


def test_state_dir_is_private(tmp_path):
    p = ensure_state_dir(Config(state_dir=str(tmp_path / "s")))
    assert p.stat().st_mode & 0o777 == 0o700


class LineageArm(FakeArm):
    async def history(self, project, query, budget_tokens):
        return [Memory("old-1", "old fact", 3, None, self.name)]

    async def source(self, memory_id):
        if memory_id == "missing":
            return None
        return SourceRecord(memory_id, "ref", "raw text", datetime(2025, 1, 1, tzinfo=timezone.utc))


async def test_history_and_source_with_unsupported_fallback_and_logging(config, tmp_path):
    g = gw(config, tmp_path, {"l": LineageArm("l"), "plain": FakeArm("plain")})
    out = await g.history("p", "q", 100, None)
    assert [m.id for m in out["results"]["l"]] == ["old-1"]
    assert out["errors"] == {"plain": "unsupported"}

    s = await g.source("l", "x")
    assert s["source"]["text"] == "raw text" and s["source"]["ts"].startswith("2025-01-01")
    assert s["error"] is None
    assert (await g.source("l", "missing")) == {"arm": "l", "source": None, "error": None}
    assert (await g.source("plain", "x"))["error"] == "unsupported"
    assert (await g.source("nope", "x"))["error"] == "unknown arm"
    await g.recall("p", "q", 100, ["l"])

    lines = [json.loads(x) for x in (tmp_path / "recall-log.jsonl").read_text().splitlines()]
    assert [x["kind"] for x in lines] == ["history", "source", "source", "source", "source", "recall"]
    assert lines[1]["request"] == {"arm": "l", "memory_id": "x"}
    g.queue.close()


async def test_http_history_source_and_ingest_arms(config, tmp_path):
    a, b = LineageArm("a"), FakeArm("b")
    app = create_app(gw(config, tmp_path, {"a": a, "b": b}))
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
            r = await c.post("/history", json={"query": "q", "budget_tokens": 50})
            assert r.json()["results"]["a"][0]["id"] == "old-1"
            assert r.json()["errors"] == {"b": "unsupported"}
            r = await c.post("/source", json={"arm": "a", "memory_id": "m"})
            assert r.json()["source"]["source_ref"] == "ref"

            body = {"session_id": "s", "source": "seed", "timestamp": "2025-01-01T00:00:00Z", "text": "x"}
            assert (await c.post("/ingest", json={**body, "arms": ["zzz"]})).status_code == 422
            assert (await c.post("/ingest", json={**body, "arms": ["a"]})).status_code == 202
            await wait_for(lambda: len(a.ingested) == 1)
            await asyncio.sleep(0.2)
            assert b.ingested == []
            assert (await c.post("/ingest", json=body)).status_code == 202
            await wait_for(lambda: len(a.ingested) == 2 and len(b.ingested) == 1)


def _rows(g):
    return g.queue._db.execute("SELECT item_id, arm FROM deliveries").fetchall()


async def test_arm_sources_filter_and_unlisted_arm_gets_all(config, tmp_path):
    config = config.model_copy(update={"arm_sources": {"a": ["session", "retain"]}})
    g = gw(config, tmp_path, {"a": FakeArm("a"), "b": FakeArm("b")})
    s = g.ingest(make_item("x", source="session"))
    d = g.ingest(make_item("y", source="seed"))
    assert sorted(_rows(g)) == [(s, "a"), (s, "b"), (d, "b")]
    g.queue.close()


async def test_explicit_arms_intersect_arm_sources(config, tmp_path):
    config = config.model_copy(update={"arm_sources": {"a": ["session"]}})
    g = gw(config, tmp_path, {"a": FakeArm("a"), "b": FakeArm("b")})
    i = g.ingest(make_item("x", source="seed"), ["a", "b"])
    assert _rows(g) == [(i, "b")]
    g.queue.close()


async def test_excluded_item_journaled_without_deliveries(config, tmp_path):
    config = config.model_copy(update={"exclude_patterns": ["memory-EVAL"]})
    g = gw(config, tmp_path, {"a": FakeArm("a")})
    g.ingest(make_item("about the memory-eval run"))
    g.ingest(make_item("normal"))
    assert g.queue._db.execute("SELECT COUNT(*) FROM items").fetchone()[0] == 2
    assert len(_rows(g)) == 1
    assert (await g.health())["excluded_total"] == 1
    g.queue.close()


class FakeExtractor:
    def __init__(self, entities=None, exc=None):
        self.entities = entities or []
        self.exc = exc
        self.queries = []

    async def extract(self, query):
        self.queries.append(query)
        if self.exc:
            raise self.exc
        return self.entities


class EntityArm(FakeArm):
    def __init__(self, name="ent"):
        super().__init__(name)
        self.seen = []

    async def recall(self, project, query, budget_tokens, entities=None):
        self.seen.append(entities)
        return await super().recall(project, query, budget_tokens)


class SpyArm(FakeArm):
    def __init__(self, name="plain"):
        super().__init__(name)
        self.kwargs = []

    async def recall(self, project, query, budget_tokens, **kwargs):
        self.kwargs.append(kwargs)
        return await super().recall(project, query, budget_tokens)


def entity_gw(config, tmp_path, extractor, **arm_map):
    return Gateway(
        config, tmp_path, arms=arm_map, poll_interval_s=0.02, entity_extractor=extractor
    )


def log_lines(tmp_path):
    return [json.loads(x) for x in (tmp_path / "recall-log.jsonl").read_text().splitlines()]


async def test_entity_aware_extracts_and_logs_entities(config, tmp_path):
    ent, ex = EntityArm(), FakeExtractor(["alice"])
    g = entity_gw(config, tmp_path, ex, ent=ent)

    await g.recall("p", "what did alice say", 100, None, entity_aware=True)

    assert ex.queries == ["what did alice say"] and ent.seen == [["alice"]]
    assert log_lines(tmp_path)[0]["request"]["entities"] == ["alice"]
    g.queue.close()


async def test_explicit_entities_skip_extraction(config, tmp_path):
    ent, ex = EntityArm(), FakeExtractor(["other"])
    g = entity_gw(config, tmp_path, ex, ent=ent)

    await g.recall("p", "q", 100, None, entities=["bob"], entity_aware=True)

    assert ex.queries == [] and ent.seen == [["bob"]]
    assert log_lines(tmp_path)[0]["request"]["entities"] == ["bob"]
    g.queue.close()


async def test_not_entity_aware_does_not_extract(config, tmp_path):
    ent, ex = EntityArm(), FakeExtractor(["alice"])
    g = entity_gw(config, tmp_path, ex, ent=ent)

    await g.recall("p", "q", 100, None)

    assert ex.queries == [] and ent.seen == [None]
    assert log_lines(tmp_path)[0]["request"]["entities"] is None
    g.queue.close()


async def test_extraction_only_when_an_arm_can_use_it(config, tmp_path):
    ex = FakeExtractor(["alice"])
    g = entity_gw(config, tmp_path, ex, plain=SpyArm())

    await g.recall("p", "q", 100, None, entity_aware=True)

    assert ex.queries == []
    g.queue.close()


async def test_extraction_failure_falls_back_to_plain_recall(config, tmp_path):
    ent = EntityArm()
    g = entity_gw(config, tmp_path, FakeExtractor(exc=RuntimeError("boom")), ent=ent)

    out = await g.recall("p", "q", 100, None, entity_aware=True)

    assert ent.seen == [None] and len(out["results"]["ent"]) == 3
    assert log_lines(tmp_path)[0]["request"]["entities"] is None
    g.queue.close()


async def test_http_recall_accepts_entities_and_entity_aware(config, tmp_path):
    ent, ex = EntityArm(), FakeExtractor(["alice"])
    app = create_app(entity_gw(config, tmp_path, ex, ent=ent))
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
            body = {"project": "p", "query": "q", "budget_tokens": 100}
            assert (await c.post("/recall", json={**body, "entities": ["bob"]})).status_code == 200
            assert (await c.post("/recall", json={**body, "entity_aware": True})).status_code == 200
            assert (await c.post("/recall", json=body)).status_code == 200

    assert ent.seen == [["bob"], ["alice"], None]
