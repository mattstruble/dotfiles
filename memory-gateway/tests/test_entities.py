import asyncio
from types import SimpleNamespace

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


async def test_failure_yields_no_entities_and_is_not_cached(config, tmp_path):
    ex, m = extractor(config, tmp_path, exc=RuntimeError("bedrock down"))

    assert await ex.extract("q") == []
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
