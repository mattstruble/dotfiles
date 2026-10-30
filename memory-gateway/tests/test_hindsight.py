import hashlib
import json
from datetime import datetime, timezone

import httpx
import respx

from memory_gateway.arms.base import IngestItem
from memory_gateway.arms.hindsight import HindsightArm
from memory_gateway.config import Config

BANK = "http://hs/v1/default/banks/memory-eval"


def arm(tmp_path):
    return HindsightArm(Config(hindsight_url="http://hs"), tmp_path)


def item(**kw):
    d = dict(project="proj", session_id="s1", source="session",
             timestamp=datetime(2025, 1, 2, tzinfo=timezone.utc), text="hello", doc_id=None)
    d.update(kw)
    return IngestItem(**d)


def _entries(route):
    return [json.loads(c.request.content)["items"][0] for c in route.calls]


@respx.mock
async def test_ingest_creates_immutable_document_with_provenance_and_project_tag(tmp_path):
    route = respx.post(f"{BANK}/memories").mock(return_value=httpx.Response(200, json={}))

    await arm(tmp_path).ingest(item())

    body = json.loads(route.calls[0].request.content)
    assert body["async"] is True
    (e,) = body["items"]
    digest = hashlib.sha256(b"hello").hexdigest()
    assert e["document_id"] == f"session:s1@20250102T000000Z#{digest[:8]}"
    assert "update_mode" not in e
    assert e["tags"] == ["project:proj"] and e["context"] == "session"
    assert e["metadata"] == {
        "base_doc": "session:s1", "source": "session", "session_id": "s1",
        "version_ts": "2025-01-02T00:00:00+00:00", "content_sha256": digest,
    }
    assert e["content"] == "hello" and e["timestamp"].startswith("2025-01-02")


@respx.mock
async def test_global_item_has_no_tags_and_versions_get_unique_ids(tmp_path):
    route = respx.post(f"{BANK}/memories").mock(return_value=httpx.Response(200, json={}))
    a = arm(tmp_path)

    await a.ingest(item(source="seed", project=None, doc_id="d1"))
    await a.ingest(item(source="seed", project=None, doc_id="d1", text="v2"))
    await a.ingest(item(source="retain", doc_id=None, text="x"))
    await a.ingest(item(source="retain", doc_id=None, text="y"))

    e1, e2, e3, e4 = _entries(route)
    assert "tags" not in e1 and "update_mode" not in e1
    assert e1["document_id"].startswith("d1@") and e1["metadata"]["base_doc"] == "d1"
    assert e1["document_id"] != e2["document_id"]
    assert e3["document_id"].startswith("retain:s1@")
    assert e3["document_id"] != e4["document_id"]


@respx.mock
async def test_recall_filters_by_project_tag_and_respects_budget(tmp_path):
    route = respx.post(f"{BANK}/memories/recall").mock(
        return_value=httpx.Response(200, json={"results": [
            {"id": "m1", "text": "abcdefgh", "occurred_start": "2025-01-01T00:00:00Z", "document_id": "d"},
            {"id": "m2", "text": "x" * 400},
        ]})
    )

    out = await arm(tmp_path).recall("proj", "q", 10)

    body = json.loads(route.calls[0].request.content)
    assert body["tags"] == ["project:proj"] and body["tags_match"] == "any"
    assert body["max_tokens"] == 10 and body["prefer_observations"] is True
    assert [m.id for m in out] == ["m1"]
    assert (out[0].tokens, out[0].source_ref, out[0].arm) == (2, "d", "hindsight")


@respx.mock
async def test_forget_invalidates_facts_behind_observations(tmp_path):
    respx.post(f"{BANK}/memories/recall").mock(
        return_value=httpx.Response(200, json={"results": [
            {"id": "m1", "text": "a"},
            {"id": "o1", "text": "obs", "type": "observation", "source_fact_ids": ["m2", "m1"]},
        ]})
    )
    patch = respx.patch(url__regex=rf"{BANK}/memories/.*").mock(return_value=httpx.Response(200, json={}))

    ids = await arm(tmp_path).forget("proj", "a", "outdated")

    assert ids == ["m1", "m2"]
    assert [c.request.url.path.rsplit("/", 1)[1] for c in patch.calls] == ["m1", "m2"]
    assert json.loads(patch.calls[0].request.content) == {"state": "invalidated", "reason": "outdated"}


@respx.mock
async def test_start_creates_missing_bank(tmp_path):
    put = respx.put(BANK).mock(return_value=httpx.Response(200, json={}))

    await arm(tmp_path).start()

    assert put.called and json.loads(put.calls[0].request.content) == {}


@respx.mock
async def test_404_on_retain_creates_bank_and_retries(tmp_path):
    route = respx.post(f"{BANK}/memories").mock(
        side_effect=[httpx.Response(404), httpx.Response(200, json={})]
    )
    put = respx.put(BANK).mock(return_value=httpx.Response(200, json={}))

    await arm(tmp_path).ingest(item())

    assert put.called and route.call_count == 2


@respx.mock
async def test_health_reflects_server_status(tmp_path):
    h = respx.get("http://hs/health").mock(return_value=httpx.Response(200, json={}))
    assert await arm(tmp_path).health() == "ok"
    h.mock(return_value=httpx.Response(503))
    assert (await arm(tmp_path).health()).startswith("error:")
