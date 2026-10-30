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


def _docs(*items):
    return httpx.Response(200, json={"items": [
        {"id": i, "document_metadata": {"base_doc": b, "version_ts": v}} for i, b, v in items
    ]})


@respx.mock
async def test_history_all_paths_sorted_and_budgeted(tmp_path):
    respx.get(f"{BANK}/documents").mock(return_value=_docs(
        ("b@1#a", "b", "2025-01-01T00:00:00+00:00"),
        ("b@2#c", "b", "2025-03-01T00:00:00+00:00"),
        ("c@1#d", "c", "2025-01-01T00:00:00+00:00"),
    ))

    def recall(request):
        if json.loads(request.content)["prefer_observations"]:
            return httpx.Response(200, json={"results": [
                {"id": "o1", "text": "obs now", "type": "observation"}]})
        return httpx.Response(200, json={"results": [
            {"id": "f1", "text": "old fact", "type": "world", "document_id": "b@1#a"},
            {"id": "f2", "text": "current fact", "type": "world", "document_id": "b@2#c"},
            {"id": "f3", "text": "unchanged", "type": "world", "document_id": "c@1#d"},
            {"id": "o2", "text": "obs", "type": "observation"},
        ]})

    respx.post(f"{BANK}/memories/recall").mock(side_effect=recall)
    lst = respx.get(f"{BANK}/memories/list").mock(return_value=httpx.Response(200, json={"items": [
        {"id": "i1", "text": "bad fact", "invalidated_at": "2025-02-01T00:00:00+00:00"}]}))
    respx.get(f"{BANK}/memories/o1/history").mock(return_value=httpx.Response(200, json=[
        {"previous_text": "obs before", "changed_at": "2025-04-01T00:00:00+00:00"}]))

    mems = await arm(tmp_path).history("proj", "q", 1000)

    assert [m.id for m in mems] == ["o1@2025-04-01T00:00:00+00:00", "f1", "i1"]
    assert mems[0].text == "[superseded 2025-04-01] obs before"
    assert mems[1].text == "[superseded 2025-03-01] old fact"
    assert mems[2].text.startswith("[invalidated 2025-02-01] ")
    assert lst.calls[0].request.url.params["state"] == "invalidated"
    small = await arm(tmp_path).history("proj", "q", mems[0].tokens)
    assert [m.id for m in small] == [mems[0].id]


@respx.mock
async def test_source_uses_chunk(tmp_path):
    respx.get(f"{BANK}/memories/m1").mock(return_value=httpx.Response(200, json={
        "id": "m1", "type": "world", "document_id": "d@1#x", "chunk_id": "c1"}))
    respx.get(f"{BANK}/documents/d@1#x").mock(return_value=httpx.Response(200, json={
        "created_at": "2025-01-01T00:00:00Z", "original_text": "full",
        "document_metadata": {"version_ts": "2025-01-02T00:00:00+00:00"}}))
    respx.get("http://hs/v1/default/chunks/c1").mock(
        return_value=httpx.Response(200, json={"chunk_text": "chunk"}))

    rec = await arm(tmp_path).source("m1")

    assert (rec.text, rec.source_ref) == ("chunk", "d@1#x")
    assert rec.ts == datetime(2025, 1, 2, tzinfo=timezone.utc)


@respx.mock
async def test_source_falls_back_to_document_then_chunks(tmp_path):
    respx.get(f"{BANK}/memories/m1").mock(return_value=httpx.Response(200, json={
        "id": "m1", "document_id": "d1"}))
    respx.get(f"{BANK}/memories/m2").mock(return_value=httpx.Response(200, json={
        "id": "m2", "document_id": "d2"}))
    respx.get(f"{BANK}/documents/d1").mock(return_value=httpx.Response(200, json={
        "created_at": "2025-01-01T00:00:00Z", "original_text": "full"}))
    respx.get(f"{BANK}/documents/d2").mock(return_value=httpx.Response(200, json={
        "created_at": "2025-01-01T00:00:00Z", "original_text": None}))
    respx.get(f"{BANK}/documents/d2/chunks").mock(return_value=httpx.Response(200, json={"items": [
        {"chunk_index": 1, "chunk_text": "B"}, {"chunk_index": 0, "chunk_text": "A"}]}))

    a = arm(tmp_path)
    r1, r2 = await a.source("m1"), await a.source("m2")

    assert r1.text == "full" and r1.ts == datetime(2025, 1, 1, tzinfo=timezone.utc)
    assert r2.text == "A\nB"


@respx.mock
async def test_source_observation_recurses_to_first_source_fact_and_missing_is_none(tmp_path):
    respx.get(f"{BANK}/memories/o").mock(return_value=httpx.Response(200, json={
        "id": "o", "type": "observation", "document_id": None, "source_memory_ids": ["f"]}))
    respx.get(f"{BANK}/memories/f").mock(return_value=httpx.Response(200, json={
        "id": "f", "document_id": "d"}))
    respx.get(f"{BANK}/documents/d").mock(return_value=httpx.Response(200, json={
        "created_at": "2025-01-01T00:00:00Z", "original_text": "raw"}))
    respx.get(f"{BANK}/memories/nope").mock(return_value=httpx.Response(404))

    a = arm(tmp_path)
    rec = await a.source("o")

    assert (rec.memory_id, rec.source_ref, rec.text) == ("o", "d", "raw")
    assert await a.source("nope") is None


@respx.mock
async def test_history_isolates_failing_paths(tmp_path):
    respx.get(f"{BANK}/documents").mock(return_value=httpx.Response(500))
    respx.post(f"{BANK}/memories/recall").mock(return_value=httpx.Response(200, json={"results": [
        {"id": "o1", "text": "obs", "type": "observation"}]}))
    respx.get(f"{BANK}/memories/list").mock(return_value=httpx.Response(200, json={"items": [
        {"id": "i1", "text": "bad fact", "invalidated_at": "2025-02-01T00:00:00+00:00"}]}))
    respx.get(f"{BANK}/memories/o1/history").mock(return_value=httpx.Response(500))

    mems = await arm(tmp_path).history("proj", "q", 1000)

    assert [m.id for m in mems] == ["i1"]
