import json
import time
from datetime import datetime, timezone

import httpx
import respx

from memory_gateway.arms import REGISTRY, load_arm
from memory_gateway.arms.base import IngestItem
from memory_gateway.arms.cognee import CogneeArm, dataset_name
from memory_gateway.config import Config

URL = "http://cg"
DS = [
    {"id": "id-proj", "name": "project_proj"},
    {"id": "id-glob", "name": "global"},
]


def arm(tmp_path):
    a = CogneeArm(Config(cognee_url=URL), tmp_path)
    a.poll_interval_s = 0
    return a


def item(**kw):
    d = dict(project="proj", session_id="s1", source="session",
             timestamp=datetime(2025, 1, 2, tzinfo=timezone.utc), text="hello", doc_id=None)
    d.update(kw)
    return IngestItem(**d)


def mock_pipeline():
    add = respx.post(f"{URL}/api/v1/add").mock(return_value=httpx.Response(200, json={}))
    cog = respx.post(f"{URL}/api/v1/cognify").mock(return_value=httpx.Response(200, json={}))
    respx.get(f"{URL}/api/v1/datasets").mock(return_value=httpx.Response(200, json=DS))
    respx.get(f"{URL}/api/v1/datasets/status").mock(
        return_value=httpx.Response(200, json={"id-proj": "DATASET_PROCESSING_COMPLETED"})
    )
    return add, cog


def chunk(cid, text, doc="d@20250102T000000Z#abcd1234"):
    return {"id": cid, "text": text, "document_id": "data-" + cid, "document_name": doc}


def test_registry_and_dataset_names(tmp_path):
    assert "cognee" in REGISTRY
    assert isinstance(load_arm("cognee", Config(), tmp_path), CogneeArm)
    assert dataset_name(None) == "global"
    assert dataset_name("a/b c:d") == "project_a_b_c_d"


@respx.mock
async def test_ingest_uploads_immutable_named_document_to_project_dataset(tmp_path):
    add, _ = mock_pipeline()

    await arm(tmp_path).ingest(item())

    body = add.calls[0].request.content.decode()
    assert 'filename="session:s1@20250102T000000Z#2cf24dba.txt"' in body
    assert "project_proj" in body and "hello" in body


@respx.mock
async def test_new_version_gets_a_distinct_document_name(tmp_path):
    add, _ = mock_pipeline()
    a = arm(tmp_path)

    await a.ingest(item(doc_id="d"))
    await a.ingest(item(doc_id="d", timestamp=datetime(2025, 1, 3, tzinfo=timezone.utc)))

    bodies = [c.request.content.decode() for c in add.calls]
    assert "d@20250102T000000Z#" in bodies[0] and "d@20250103T000000Z#" in bodies[1]


@respx.mock
async def test_cognify_is_batched_then_flushed(tmp_path):
    add, cog = mock_pipeline()
    a = arm(tmp_path)

    await a.ingest(item(text="t0"))
    await a.settle()
    for i in (1, 2):
        await a.ingest(item(text=f"t{i}"))
    await a.settle()
    assert len(add.calls) == 3
    assert len(cog.calls) == 1  # first add cognifies; the rest wait
    await a.flush()
    assert len(cog.calls) == 2
    await a.flush()

    assert len(cog.calls) == 2
    assert json.loads(cog.calls[0].request.content)["run_in_background"] is True


@respx.mock
async def test_cognify_after_20_pending_adds(tmp_path):
    _, cog = mock_pipeline()
    a = arm(tmp_path)
    a._last_cognify["project_proj"] = time.monotonic()

    for i in range(20):
        await a.ingest(item(text=f"t{i}"))
        if i < 19:
            assert not cog.calls
    await a.settle()

    assert len(cog.calls) == 1
    await a.flush()


@respx.mock
async def test_cognify_polls_until_complete(tmp_path):
    mock_pipeline()
    st = respx.get(f"{URL}/api/v1/datasets/status").mock(side_effect=[
        httpx.Response(200, json={"id-proj": "DATASET_PROCESSING_STARTED"}),
        httpx.Response(200, json={"id-proj": "DATASET_PROCESSING_COMPLETED"}),
    ])

    a = arm(tmp_path)
    await a.ingest(item())
    await a.settle()

    assert st.call_count == 2


@respx.mock
async def test_recall_searches_project_and_global_context_only(tmp_path):
    mock_pipeline()
    route = respx.post(f"{URL}/api/v1/search").mock(return_value=httpx.Response(200, json=[
        {"dataset_id": "id-glob", "search_result": [chunk("g1", "global fact")]},
        {"dataset_id": "id-proj", "search_result": [chunk("p1", "proj fact"), chunk("g1", "dup")]},
    ]))

    mems = await arm(tmp_path).recall("proj", "q", 1000)

    sent = json.loads(route.calls[0].request.content)
    assert sent["search_type"] == "CHUNKS" and sent["dataset_ids"] == ["id-proj", "id-glob"]
    assert [m.id for m in mems] == ["p1", "g1"]  # project first, deduped
    assert mems[0].source_ref == "d@20250102T000000Z#abcd1234"
    assert mems[0].ts == datetime(2025, 1, 2, tzinfo=timezone.utc) and mems[0].arm == "cognee"


@respx.mock
async def test_recall_skips_missing_datasets(tmp_path):
    respx.get(f"{URL}/api/v1/datasets").mock(
        return_value=httpx.Response(200, json=[{"id": "id-glob", "name": "global"}])
    )
    route = respx.post(f"{URL}/api/v1/search").mock(return_value=httpx.Response(200, json=[]))

    await arm(tmp_path).recall("proj", "q", 100)

    assert json.loads(route.calls[0].request.content)["dataset_ids"] == ["id-glob"]


@respx.mock
async def test_recall_with_no_datasets_makes_no_search(tmp_path):
    respx.get(f"{URL}/api/v1/datasets").mock(return_value=httpx.Response(200, json=[]))
    route = respx.post(f"{URL}/api/v1/search")

    assert await arm(tmp_path).recall(None, "q", 100) == []
    assert not route.called


@respx.mock
async def test_recall_budget_cap(tmp_path):
    mock_pipeline()
    respx.post(f"{URL}/api/v1/search").mock(return_value=httpx.Response(200, json=[
        {"dataset_id": "id-proj", "search_result": [
            chunk("a", "x" * 40), chunk("b", "y" * 40), chunk("c", "z" * 8)]},
    ]))

    mems = await arm(tmp_path).recall("proj", "q", 12)

    assert [m.id for m in mems] == ["a", "c"]
    assert sum(m.tokens for m in mems) <= 12


@respx.mock
async def test_forget_makes_no_http_call(tmp_path):
    assert await arm(tmp_path).forget("proj", "x", "wrong") == []
    assert len(respx.calls) == 0


@respx.mock
async def test_source_returns_document_text_for_recalled_chunk(tmp_path):
    mock_pipeline()
    respx.post(f"{URL}/api/v1/search").mock(return_value=httpx.Response(200, json=[
        {"dataset_id": "id-proj", "search_result": [chunk("p1", "fact")]},
    ]))
    raw = respx.get(f"{URL}/api/v1/datasets/id-proj/data/data-p1/raw").mock(
        return_value=httpx.Response(200, text="full doc"))
    a = arm(tmp_path)

    assert await a.source("unknown") is None
    await a.recall("proj", "q", 100)
    rec = await a.source("p1")

    assert raw.called and rec.text == "full doc" and rec.source_ref.startswith("d@")


@respx.mock
async def test_health(tmp_path):
    respx.get(f"{URL}/health").mock(return_value=httpx.Response(200, json={}))
    assert await arm(tmp_path).health() == "ok"

    respx.get(f"{URL}/health").mock(return_value=httpx.Response(503))
    assert (await arm(tmp_path).health()).startswith("error")


def test_history_is_not_defined(tmp_path):
    assert not hasattr(arm(tmp_path), "history")


@respx.mock
async def test_cognify_failure_does_not_fail_ingest(tmp_path):
    mock_pipeline()
    respx.post(f"{URL}/api/v1/cognify").mock(return_value=httpx.Response(500))
    a = arm(tmp_path)

    await a.ingest(item())
    await a.settle()

    assert a._pending["project_proj"] == 1  # retried with the next batch


@respx.mock
async def test_poll_gives_up_at_deadline(tmp_path):
    mock_pipeline()
    respx.get(f"{URL}/api/v1/datasets/status").mock(
        return_value=httpx.Response(200, json={"id-proj": "DATASET_PROCESSING_STARTED"}))
    a = arm(tmp_path)
    a.cognify_timeout_s = 0.05
    a.poll_interval_s = 0.01

    await a.ingest(item())
    await a.settle()

    assert a._pending["project_proj"] == 1
