import json
from types import SimpleNamespace

import httpx
import respx

from memory_gateway.arms import graphiti as graphiti_mod
from memory_gateway.arms.hindsight import HindsightArm
from memory_gateway.config import Config
from memory_gateway.usage import UsageRecordingClient, record_usage
from tests.test_wiki_arm import fake_embed, item, make, source  # noqa: F401


def lines(d):
    return [json.loads(x) for x in (d / "llm-usage.jsonl").read_text().splitlines()]


class UsageClient:
    def __init__(self):
        self.messages = self
        self.resp = SimpleNamespace(
            content=[SimpleNamespace(type="tool_use", input={"ops": []})],
            usage=SimpleNamespace(input_tokens=11, output_tokens=7),
        )

    async def create(self, **kw):
        return self.resp


def test_record_usage_line(tmp_path):
    record_usage(tmp_path, "wiki", "extract", 3, 4, "m")
    (row,) = lines(tmp_path)
    assert {k: row[k] for k in row if k != "ts"} == dict(
        arm="wiki", op="extract", input_tokens=3, output_tokens=4, model="m")
    assert row["ts"]
    assert (tmp_path / "llm-usage.jsonl").stat().st_mode & 0o777 == 0o600


def test_record_usage_survives_unwritable_dir(tmp_path):
    record_usage(tmp_path / "missing" / "dir", "wiki", "extract", 1, 1, "m")


async def test_wiki_records_extract_usage(tmp_path, source):  # noqa: F811
    arm = make(tmp_path, source, UsageClient())
    await arm.start()
    await arm.ingest(item())
    (row,) = lines(tmp_path / "state")
    assert (row["arm"], row["op"], row["input_tokens"], row["output_tokens"]) == ("wiki", "extract", 11, 7)


async def test_graphiti_proxy_records_and_returns_response(tmp_path):
    inner = UsageClient()
    proxy = UsageRecordingClient(inner, tmp_path, "graphiti", "graphiti")
    assert await proxy.messages.create(model="m", max_tokens=1) is inner.resp
    (row,) = lines(tmp_path)
    assert (row["arm"], row["op"], row["input_tokens"], row["output_tokens"], row["model"]) == (
        "graphiti", "graphiti", 11, 7, "m")


def test_graphiti_make_llm_wraps_bedrock_client(tmp_path, monkeypatch):
    import anthropic

    monkeypatch.setattr(anthropic, "AsyncAnthropicBedrock", lambda **kw: UsageClient())
    llm = graphiti_mod._make_llm(Config(), tmp_path)
    assert isinstance(llm.client, UsageRecordingClient)


@respx.mock
async def test_hindsight_usage_sums_trace_stats(tmp_path):
    respx.get("http://hs/v1/default/banks/memory-eval/llm-requests/stats").mock(
        return_value=httpx.Response(200, json={"buckets": [
            {"tokens": {"input": 5, "output": 2}}, {"tokens": {"input": 1, "output": 1}}]}))
    arm = HindsightArm(Config(hindsight_url="http://hs"), tmp_path)
    assert await arm.usage() == {"input_tokens": 6, "output_tokens": 3}


class Sdk23Client:
    """messages.create with the anthropic 2.3 keyword-only signature (no sampling kwargs)."""

    def __init__(self):
        self.messages = self
        self.kw = None

    async def create(self, *, max_tokens, messages=None, model=None, system=None,
                     extra_body=None, timeout=None):
        self.kw = dict(max_tokens=max_tokens, model=model, system=system, extra_body=extra_body)
        return SimpleNamespace(usage=SimpleNamespace(input_tokens=1, output_tokens=2))


async def test_proxy_drops_sampling_params(tmp_path):
    inner = Sdk23Client()
    proxy = UsageRecordingClient(inner, tmp_path, "graphiti", "graphiti")
    eb = {"x": 1, "temperature": 0.1, "top_k": 3}
    await proxy.messages.create(model="m", max_tokens=5, system="s", temperature=0.3,
                                top_p=0.9, top_k=40, extra_body=eb)
    assert inner.kw == dict(max_tokens=5, model="m", system="s", extra_body={"x": 1})
    assert eb == {"x": 1, "temperature": 0.1, "top_k": 3}


async def test_proxy_omits_empty_extra_body(tmp_path):
    inner = Sdk23Client()
    proxy = UsageRecordingClient(inner, tmp_path, "graphiti", "graphiti")
    await proxy.messages.create(model="m", max_tokens=5, temperature=0,
                                extra_body={"temperature": 0})
    assert inner.kw["extra_body"] is None
