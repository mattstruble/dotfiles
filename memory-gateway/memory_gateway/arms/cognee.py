"""Cognee arm over the cognee 1.6.6 HTTP API (cognee/api/client.py at tag v1.6.6).

Endpoints used, and why:

- ``POST /api/v1/add`` (multipart: ``data`` file upload, ``datasetName``). A file
  upload, not ``raw_data``, because the upload's filename becomes the document
  name, which lets us give every version an immutable, self-describing name.
  The call blocks until the document is stored, so ingest is durable on return.
  A same-named file with different content would 409 (add never updates); our
  names embed a content hash, so each version is a new document.
- ``POST /api/v1/cognify`` (JSON: ``datasets``, ``run_in_background=true``) builds
  the graph; ``GET /api/v1/datasets/status?datasets=<id>&pipelines=cognify_pipeline``
  is polled until the run completes or errors. Cognify is LLM-expensive, so it is
  batched per dataset (at most one per 60 s or after 20 adds).
- ``GET /api/v1/datasets`` maps dataset names to ids, so recall skips datasets
  that do not exist yet.
- ``POST /api/v1/search`` with ``search_type=CHUNKS``: pure vector retrieval that
  returns chunk payloads (``id``, ``text``, ``document_id``, ``document_name``) and
  makes no LLM call. The graph-aware types (GRAPH_COMPLETION & co.) either call
  an LLM or return an unstructured context string without chunk ids, so they are
  not used; recall therefore returns source chunks, not graph triplets.
- ``GET /api/v1/datasets/{dataset_id}/data/{data_id}/raw`` returns the stored
  document text; used by ``source()``.
- ``GET /health`` for liveness.

Not used: ``DELETE /api/v1/datasets/...`` (destructive). ``forget`` is a no-op
because cognee has no non-destructive invalidation; the eval should record this
gap. ``history`` is not defined: the TEMPORAL search type answers time-scoped
questions over events and does not surface superseded facts or older document
versions.

Dataset names are ``project_<sanitised project>`` or ``global`` (``[A-Za-z0-9_-]``
only; cognee rejects dots and spaces, and names end up in storage paths).

LLM usage: cognee's REST responses carry no token counts, so nothing is written
to llm-usage.jsonl for this arm; its cost comes from Bedrock metrics.
"""

import asyncio
import hashlib
import logging
import re
import time
from collections import OrderedDict
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

import httpx

from ..config import Config
from .base import IngestItem, Memory, SourceRecord, count_tokens

log = logging.getLogger(__name__)

COGNIFY_INTERVAL_S = 60.0
COGNIFY_MAX_PENDING = 20
GLOBAL_DATASET = "global"
SEARCH_TOP_K = 15
CHUNK_CACHE_MAX = 5000
_DOC_TS = re.compile(r"@(\d{8}T\d{6}Z)#")


def dataset_name(project: str | None) -> str:
    if project is None:
        return GLOBAL_DATASET
    return "project_" + re.sub(r"[^A-Za-z0-9_-]", "_", project)


def _q(x) -> str:
    return quote(str(x), safe="")


def _doc_ts(name: str | None) -> datetime | None:
    m = _DOC_TS.search(name or "")
    return datetime.strptime(m[1], "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc) if m else None


def _epoch_ms(v) -> datetime | None:
    try:
        return datetime.fromtimestamp(int(v) / 1000, tz=timezone.utc)
    except (TypeError, ValueError, OverflowError, OSError):
        return None


def _score(chunk: dict) -> float | None:
    try:
        return float(chunk["score"])
    except (KeyError, TypeError, ValueError):
        return None


def _flatten(body, ds_id: str) -> list[tuple[str, dict]]:
    """Accept a flat chunk list or the grouped ``[{dataset_id, search_result}]`` shape."""
    out: list[tuple[str, dict]] = []
    for el in body if isinstance(body, list) else []:
        if not isinstance(el, dict):
            continue
        if "search_result" in el:
            gid = str(el.get("dataset_id") or ds_id)
            out.extend((gid, c) for c in el.get("search_result") or [] if isinstance(c, dict))
        else:
            out.append((ds_id, el))
    return out


class CogneeArm:
    name = "cognee"

    def __init__(
        self,
        config: Config,
        state_dir: Path,
        client: httpx.AsyncClient | None = None,
    ):
        self.base = config.cognee_url.rstrip("/")
        self.client = client or httpx.AsyncClient(timeout=config.ingest_timeout_s)
        self.poll_interval_s = 2.0
        self._pending: dict[str, int] = {}
        self._last_cognify: dict[str, float] = {}
        self._timers: dict[str, asyncio.Task] = {}
        self._running: set[asyncio.Task] = set()
        self.cognify_timeout_s = config.ingest_timeout_s
        self._locks: dict[str, asyncio.Lock] = {}
        self._chunks: OrderedDict[str, tuple[str, str, str | None]] = OrderedDict()

    async def start(self) -> None:
        return None

    async def health(self) -> str:
        try:
            r = await self.client.get(f"{self.base}/health")
            r.raise_for_status()
            return "ok"
        except httpx.HTTPError as e:
            return f"error: {e}"

    # --- ingest ------------------------------------------------------------

    async def ingest(self, item: IngestItem) -> None:
        base = item.doc_id or f"{item.source}:{item.session_id}"
        ts = item.timestamp
        ts_utc = ts.astimezone(timezone.utc) if ts.tzinfo else ts.replace(tzinfo=timezone.utc)
        digest = hashlib.sha256(item.text.encode()).hexdigest()
        doc = f"{base}@{ts_utc.strftime('%Y%m%dT%H%M%SZ')}#{digest[:8]}"
        filename = doc.replace("/", "_").replace("\\", "_") + ".txt"
        ds = dataset_name(item.project)
        r = await self.client.post(
            f"{self.base}/api/v1/add",
            data={"datasetName": ds},
            files={"data": (filename, item.text.encode(), "text/plain")},
        )
        r.raise_for_status()
        self._pending[ds] = self._pending.get(ds, 0) + 1
        await self._maybe_cognify(ds)

    async def _maybe_cognify(self, ds: str) -> None:
        """Schedule cognify in the background; the add is already durable."""
        elapsed = time.monotonic() - self._last_cognify.get(ds, float("-inf"))
        if self._pending[ds] >= COGNIFY_MAX_PENDING or elapsed >= COGNIFY_INTERVAL_S:
            if (t := self._timers.pop(ds, None)) is not None:
                t.cancel()
            self._spawn(ds, 0.0)
        elif ds not in self._timers:
            self._timers[ds] = self._spawn(ds, COGNIFY_INTERVAL_S - elapsed, timer=True)

    def _spawn(self, ds: str, delay: float, timer: bool = False) -> asyncio.Task:
        task = asyncio.create_task(self._cognify_later(ds, delay, timer))
        if not timer:  # sleeping timers join _running only once they wake
            self._track(task)
        return task

    def _track(self, task: asyncio.Task) -> None:
        self._running.add(task)
        task.add_done_callback(self._running.discard)

    async def _cognify_later(self, ds: str, delay: float, timer: bool) -> None:
        if delay:
            await asyncio.sleep(delay)
        if timer:
            self._timers.pop(ds, None)
            self._track(asyncio.current_task())
        try:
            await self._cognify(ds)
        except (httpx.HTTPError, RuntimeError):
            log.exception("cognify failed for dataset %s; adds stay stored", ds)

    async def settle(self) -> None:
        """Wait for in-flight and scheduled cognify runs."""
        while self._running:
            await asyncio.gather(*self._running, return_exceptions=True)

    async def flush(self) -> None:
        """Cognify every dataset with pending adds now."""
        for t in self._timers.values():
            t.cancel()
        self._timers.clear()
        await self.settle()
        for ds, n in list(self._pending.items()):
            if n:
                await self._cognify(ds)

    async def _cognify(self, ds: str) -> None:
        lock = self._locks.setdefault(ds, asyncio.Lock())
        async with lock:
            batch = self._pending.get(ds, 0)
            if not batch:
                return
            self._pending[ds] -= batch
            self._last_cognify[ds] = time.monotonic()
            try:
                r = await self.client.post(
                    f"{self.base}/api/v1/cognify",
                    json={"datasets": [ds], "run_in_background": True},
                )
                r.raise_for_status()
                await self._wait_cognify(ds)
            except (httpx.HTTPError, RuntimeError):
                self._pending[ds] += batch  # retry with the next batch
                raise

    async def _wait_cognify(self, ds: str) -> None:
        ds_id = (await self._datasets()).get(ds)
        if ds_id is None:
            raise RuntimeError(f"cognee dataset {ds} not found after add")
        deadline = time.monotonic() + self.cognify_timeout_s
        while time.monotonic() < deadline:
            r = await self.client.get(
                f"{self.base}/api/v1/datasets/status",
                params={"datasets": ds_id, "pipelines": "cognify_pipeline"},
            )
            r.raise_for_status()
            status = str(r.json().get(ds_id, ""))
            if status.endswith("ERRORED"):
                raise RuntimeError(f"cognee cognify failed for {ds}: {status}")
            if status.endswith("COMPLETED"):
                return
            await asyncio.sleep(self.poll_interval_s)
        raise RuntimeError(f"cognee cognify for {ds} not finished after {self.cognify_timeout_s}s")

    # --- recall ------------------------------------------------------------

    async def _datasets(self) -> dict[str, str]:
        r = await self.client.get(f"{self.base}/api/v1/datasets")
        r.raise_for_status()
        return {d["name"]: d["id"] for d in r.json()}

    async def recall(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        known = await self._datasets()
        names = [n for n in dict.fromkeys([dataset_name(project), GLOBAL_DATASET]) if n in known]
        if not names:
            return []
        out: list[Memory] = []
        seen: set[str] = set()
        used = 0
        for n in names:
            ds_id = known[n]
            r = await self.client.post(
                f"{self.base}/api/v1/search",
                json={
                    "search_type": "CHUNKS",
                    "query": query,
                    "dataset_ids": [ds_id],
                    "top_k": SEARCH_TOP_K,
                },
            )
            if r.status_code == 404:
                continue
            r.raise_for_status()
            chunks = _flatten(r.json(), ds_id)
            chunks.sort(key=lambda c: (c[1].get("score") is None, -(_score(c[1]) or 0.0)))
            for chunk_ds, chunk in chunks:
                if not chunk.get("text") or chunk.get("id") is None:
                    continue
                cid = str(chunk["id"])
                tok = count_tokens(chunk["text"])
                if cid in seen or used + tok > budget_tokens:
                    continue
                seen.add(cid)
                used += tok
                doc_name = chunk.get("document_name")
                if chunk.get("document_id"):
                    self._remember(cid, (chunk_ds, str(chunk["document_id"]), doc_name))
                out.append(
                    Memory(
                        id=cid,
                        text=chunk["text"],
                        tokens=tok,
                        ts=_doc_ts(doc_name) or _epoch_ms(chunk.get("created_at")),
                        arm=self.name,
                        source_ref=doc_name,
                    )
                )
        return out

    def _remember(self, cid: str, ref: tuple[str, str, str | None]) -> None:
        self._chunks[cid] = ref
        self._chunks.move_to_end(cid)
        while len(self._chunks) > CHUNK_CACHE_MAX:
            self._chunks.popitem(last=False)

    async def forget(self, project: str | None, text: str, reason: str) -> list[str]:
        log.warning(
            "cognee has no non-destructive invalidation; forget(%r) ignored (reason: %s)",
            text, reason,
        )
        return []

    async def source(self, memory_id: str) -> SourceRecord | None:
        ref = self._chunks.get(memory_id)
        if ref is None:
            return None
        ds_id, data_id, doc_name = ref
        r = await self.client.get(
            f"{self.base}/api/v1/datasets/{_q(ds_id)}/data/{_q(data_id)}/raw"
        )
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return SourceRecord(
            memory_id=memory_id, source_ref=doc_name, text=r.text, ts=_doc_ts(doc_name)
        )
