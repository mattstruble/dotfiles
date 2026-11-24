import asyncio
from types import SimpleNamespace

from memory_gateway import entities as entities_mod
from memory_gateway.entities import CACHE_SIZE, EntityExtractor, clean_entities


class FakeMessages:
    def __init__(self, entities=None, exc=None, delay=0.0):
        self.entities = entities
        self.exc = exc
        self.delay = delay
        self.calls = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        await asyncio.sleep(self.delay)
        if self.exc:
            raise self.exc
        block = SimpleNamespace(
            type="tool_use", name="extract_entities", input={"entities": self.entities}
        )
        return SimpleNamespace(content=[SimpleNamespace(type="text", text="hi"), block])


def fake_clock(monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(entities_mod, "time", SimpleNamespace(monotonic=lambda: now[0]))  # not the event loop clock
    return now


def extractor(config, tmp_path, **kw):
    messages = FakeMessages(**kw)
    return EntityExtractor(config, tmp_path, client=SimpleNamespace(messages=messages)), messages


async def test_extract_is_cached_per_query(config, tmp_path):
    ex, m = extractor(config, tmp_path, entities=["alice"])

    await ex.extract("q1")
    await ex.extract("q1")
    await ex.extract("q2")

    assert len(m.calls) == 2


async def test_cache_evicts_least_recently_used(config, tmp_path):
    ex, m = extractor(config, tmp_path, entities=["a"])
    for i in range(CACHE_SIZE):
        await ex.extract(f"q{i}")
    await ex.extract("q0")  # refresh q0
    await ex.extract("new")  # evicts q1, not q0
    n = len(m.calls)

    await ex.extract("q0")
    assert len(m.calls) == n
    await ex.extract("q1")
    assert len(m.calls) == n + 1


async def test_failure_yields_no_entities_and_is_retried_after_the_negative_ttl(
    config, tmp_path, monkeypatch
):
    now = fake_clock(monkeypatch)
    ex, m = extractor(config, tmp_path, exc=RuntimeError("bedrock down"))

    assert await ex.extract("q") == []
    assert await ex.extract("q") == []
    assert len(m.calls) == 1  # negative cached

    now[0] += 61
    assert await ex.extract("q") == []
    assert len(m.calls) == 2


async def test_timeout_yields_no_entities(config, tmp_path):
    config.entity_timeout_s = 0.05
    ex, _ = extractor(config, tmp_path, entities=["alice"], delay=1.0)

    assert await ex.extract("q") == []


def test_default_timeout_is_three_seconds(config):
    assert config.entity_timeout_s == 3.0


def test_clean_entities_trims_dedups_and_caps():
    raw = [" a ", "A", "", 3, "b", "c", "d", "e", "f"]
    assert clean_entities(raw) == ["a", "b", "c", "d", "e"]
    assert clean_entities(None) == []


# --- negative cache and circuit ------------------------------------------------------

async def test_timeout_is_negative_cached(config, tmp_path, monkeypatch):
    fake_clock(monkeypatch)
    config.entity_timeout_s = 0.05
    ex, m = extractor(config, tmp_path, entities=["a"], delay=1.0)

    await ex.extract("q")
    await ex.extract("q")

    assert len(m.calls) == 1


async def test_circuit_opens_after_three_consecutive_failures(config, tmp_path, monkeypatch):
    now = fake_clock(monkeypatch)
    ex, m = extractor(config, tmp_path, exc=RuntimeError("down"))

    for q in ("q1", "q2", "q3"):
        await ex.extract(q)
    assert await ex.extract("q4") == []
    assert len(m.calls) == 3  # circuit open: no call for a fresh query

    now[0] += 61
    m.exc = None
    m.entities = ["alice"]
    assert await ex.extract("q4") == ["alice"]
    assert len(m.calls) == 4


async def test_success_resets_consecutive_failures(config, tmp_path, monkeypatch):
    fake_clock(monkeypatch)
    ex, m = extractor(config, tmp_path, exc=RuntimeError("down"))
    await ex.extract("q1")
    await ex.extract("q2")
    m.exc = None
    m.entities = ["a"]
    await ex.extract("ok")
    m.exc = RuntimeError("down")
    await ex.extract("q3")
    await ex.extract("q4")

    assert len(m.calls) == 5  # circuit never opened


async def test_extract_forces_tool_and_uses_configured_model(config, tmp_path):
    ex, m = extractor(config, tmp_path, entities=["XYZ-123", "Alex"])

    assert await ex.extract("status of XYZ-123 from Alex") == ["XYZ-123", "Alex"]

    call = m.calls[0]
    assert call["model"] == config.entity_model
    assert call["tool_choice"] == {"type": "tool", "name": "extract_entities"}
