import asyncio
import hashlib
import logging
import time
from datetime import datetime, timezone
from pathlib import Path

import httpx

from ..config import Config
from .base import IngestItem, Memory, SourceRecord, count_tokens

log = logging.getLogger(__name__)

MAX_HISTORY_OBSERVATIONS = 5


def _parse_ts(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


class HindsightArm:
    name = "hindsight"

    def __init__(
        self,
        config: Config,
        state_dir: Path,
        client: httpx.AsyncClient | None = None,
    ):
        self.bank = config.hindsight_bank
        self.base = config.hindsight_url.rstrip("/")
        self.client = client or httpx.AsyncClient(timeout=30.0)
        self._bank_path = f"{self.base}/v1/default/banks/{self.bank}"
        self._doc_lock = asyncio.Lock()
        self._doc_cache: tuple[float, dict[str, tuple[str, datetime | None]], dict[str, datetime]] | None = None

    async def _ensure_bank(self) -> None:
        # PUT is create-or-update (idempotent); the /profile endpoints are gone in 1.1.0
        r = await self.client.put(self._bank_path, json={})
        r.raise_for_status()

    async def start(self) -> None:
        await self._ensure_bank()

    async def health(self) -> str:
        try:
            r = await self.client.get(f"{self.base}/health")
            r.raise_for_status()
            return "ok"
        except httpx.HTTPError as e:
            return f"error: {e}"

    async def _post(self, url: str, payload: dict) -> httpx.Response:
        r = await self.client.post(url, json=payload)
        if r.status_code == 404:
            # bank missing: create and retry once
            await self._ensure_bank()
            r = await self.client.post(url, json=payload)
        r.raise_for_status()
        return r

    async def ingest(self, item: IngestItem) -> None:
        base = item.doc_id or f"{item.source}:{item.session_id}"
        ts = item.timestamp
        ts_utc = (ts.astimezone(timezone.utc) if ts.tzinfo else ts.replace(tzinfo=timezone.utc))
        digest = hashlib.sha256(item.text.encode()).hexdigest()
        entry: dict = {
            "content": item.text,
            "timestamp": ts.isoformat(),
            "context": item.source,
            # unique id per version: Hindsight never replaces or appends
            "document_id": f"{base}@{ts_utc.strftime('%Y%m%dT%H%M%SZ')}#{digest[:8]}",
            "metadata": {
                "base_doc": base,
                "source": item.source,
                "session_id": str(item.session_id),
                "version_ts": ts_utc.isoformat(),
                "content_sha256": digest,
            },
        }
        if item.project:
            entry["tags"] = [f"project:{item.project}"]
        await self._post(
            f"{self._bank_path}/memories", {"items": [entry], "async": True}
        )

    async def _recall(
        self,
        project: str | None,
        query: str,
        max_tokens: int,
        prefer_observations: bool = True,
    ) -> list[dict]:
        payload: dict = {
            "query": query,
            "max_tokens": max_tokens,
            "prefer_observations": prefer_observations,
            "tags_match": "any",
        }
        if project:
            payload["tags"] = [f"project:{project}"]
        r = await self._post(f"{self._bank_path}/memories/recall", payload)
        return r.json().get("results", [])

    async def recall(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        out: list[Memory] = []
        used = 0
        for res in await self._recall(project, query, budget_tokens):
            text = res["text"]
            n = count_tokens(text)
            if used + n > budget_tokens:
                continue
            used += n
            out.append(
                Memory(
                    id=res["id"],
                    text=text,
                    tokens=n,
                    ts=_parse_ts(res.get("occurred_start") or res.get("mentioned_at")),
                    arm=self.name,
                    source_ref=res.get("document_id"),
                )
            )
        return out

    async def forget(self, project: str | None, text: str, reason: str) -> list[str]:
        targets: list[str] = []
        for res in (await self._recall(project, text, 4096))[:5]:
            # observations are derived and cannot be curated; invalidate their source facts
            ids = res.get("source_fact_ids") if res.get("type") == "observation" else None
            targets.extend(ids or [res["id"]])
        targets = list(dict.fromkeys(targets))
        for memory_id in targets:
            r = await self.client.patch(
                f"{self._bank_path}/memories/{memory_id}",
                json={"state": "invalidated", "reason": reason},
            )
            r.raise_for_status()
        return targets

    async def usage(self, period: str = "30d") -> dict:
        """LLM token totals from Hindsight's server-side request traces.

        Needs HINDSIGHT_API_LLM_TRACE_ENABLED on the server; traces older than
        its retention window are gone, so call this before they expire.
        """
        r = await self.client.get(
            f"{self._bank_path}/llm-requests/stats", params={"period": period, "call_type": "llm"}
        )
        r.raise_for_status()
        tokens = [b["tokens"] for b in r.json().get("buckets", [])]
        return {
            "input_tokens": sum(t.get("input") or 0 for t in tokens),
            "output_tokens": sum(t.get("output") or 0 for t in tokens),
        }

    # --- lineage -----------------------------------------------------------

    async def _documents(self):
        """(doc_id -> (base_doc, version_ts), base_doc -> latest version_ts), cached 60s."""
        async with self._doc_lock:
            return await self._documents_locked()

    async def _documents_locked(self):
        now = time.monotonic()
        if self._doc_cache and now - self._doc_cache[0] < 60:
            return self._doc_cache[1], self._doc_cache[2]
        docs: dict[str, tuple[str, datetime | None]] = {}
        latest: dict[str, datetime] = {}
        offset, limit = 0, 200
        while True:
            r = await self.client.get(
                f"{self._bank_path}/documents", params={"limit": limit, "offset": offset}
            )
            r.raise_for_status()
            items = r.json().get("items", [])
            for d in items:
                meta = d.get("document_metadata") or {}
                base = meta.get("base_doc")
                if not base:
                    continue
                ts = _parse_ts(meta.get("version_ts"))
                docs[d["id"]] = (base, ts)
                if ts and (base not in latest or ts > latest[base]):
                    latest[base] = ts
            offset += limit
            if len(items) < limit:
                break
        self._doc_cache = (now, docs, latest)
        return docs, latest

    async def history(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        found: dict[str, Memory] = {}

        def add(mid: str, label: str, text: str, ts: datetime | None, ref: str | None):
            full = f"[{label} {ts.date().isoformat() if ts else 'unknown date'}] {text}"
            found.setdefault(
                mid, Memory(mid, full, count_tokens(full), ts, self.name, ref)
            )

        async def path_a() -> None:
            # facts whose source document has a newer version
            docs, latest = await self._documents()
            recalled = await self._recall(
                project, query, budget_tokens, prefer_observations=False
            )
            for res in recalled:
                if res.get("type") not in ("world", "experience"):
                    continue
                info = docs.get(res.get("document_id") or "")
                if not info or not info[1] or info[0] not in latest or latest[info[0]] <= info[1]:
                    continue
                add(res["id"], "superseded", res["text"], latest[info[0]], res.get("document_id"))

        async def path_b() -> None:
            # invalidated facts matching the query
            params: dict = {"state": "invalidated", "q": query, "limit": 50}
            if project:
                params.update({"tags": f"project:{project}", "tags_match": "any"})
            r = await self.client.get(f"{self._bank_path}/memories/list", params=params)
            r.raise_for_status()
            for m in r.json().get("items", []):
                ts = _parse_ts(m.get("invalidated_at")) or _parse_ts(m.get("updated_at"))
                add(m["id"], "invalidated", m["text"], ts, m.get("document_id"))

        async def obs_history(oid: str) -> None:
            r = await self.client.get(f"{self._bank_path}/memories/{oid}/history")
            if r.status_code == 404:
                return
            r.raise_for_status()
            body = r.json()
            entries = body if isinstance(body, list) else body.get("items", [])
            for e in entries:
                if not e.get("previous_text"):
                    continue
                ts = _parse_ts(e.get("changed_at"))
                add(f"{oid}@{e.get('changed_at')}", "superseded", e["previous_text"], ts, oid)

        async def path_c() -> None:
            # prior texts of observations (capped, fetched concurrently, isolated)
            recalled = await self._recall(project, query, budget_tokens)
            ids = [x["id"] for x in recalled if x.get("type") == "observation"]
            results = await asyncio.gather(
                *(obs_history(i) for i in ids[:MAX_HISTORY_OBSERVATIONS]),
                return_exceptions=True,
            )
            for i, res in zip(ids, results):
                if isinstance(res, Exception):
                    log.warning("hindsight observation history %s failed: %s", i, res)

        for name, res in zip(
            "abc",
            await asyncio.gather(path_a(), path_b(), path_c(), return_exceptions=True),
        ):
            if isinstance(res, Exception):
                log.warning("hindsight history path %s failed: %s", name, res)

        floor = datetime.min.replace(tzinfo=timezone.utc)
        ordered = sorted(found.values(), key=lambda m: m.ts or floor, reverse=True)
        out: list[Memory] = []
        used = 0
        for m in ordered:
            if used + m.tokens > budget_tokens:
                continue
            used += m.tokens
            out.append(m)
        return out

    async def _get_json(self, url: str) -> dict | None:
        r = await self.client.get(url)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json()

    async def source(self, memory_id: str, _depth: int = 0) -> SourceRecord | None:
        mem = await self._get_json(f"{self._bank_path}/memories/{memory_id}")
        if mem is None:
            return None
        doc_id = mem.get("document_id")
        if not doc_id:
            srcs = mem.get("source_memory_ids") or mem.get("source_fact_ids") or []
            if mem.get("type") == "observation" and srcs and _depth < 1:
                rec = await self.source(srcs[0], _depth + 1)
                return SourceRecord(memory_id, rec.source_ref, rec.text, rec.ts) if rec else None
            return None
        doc = await self._get_json(f"{self._bank_path}/documents/{doc_id}") or {}
        text = None
        if mem.get("chunk_id"):
            chunk = await self._get_json(f"{self.base}/v1/default/chunks/{mem['chunk_id']}")
            text = (chunk or {}).get("chunk_text")
        if not text:
            text = doc.get("original_text")
        if not text:
            chunks = await self._get_json(f"{self._bank_path}/documents/{doc_id}/chunks")
            items = sorted((chunks or {}).get("items", []), key=lambda c: c.get("chunk_index", 0))
            text = "\n".join(c.get("chunk_text", "") for c in items) or None
        if not text:
            return None
        ts = _parse_ts((doc.get("document_metadata") or {}).get("version_ts")) or _parse_ts(
            doc.get("created_at")
        )
        return SourceRecord(memory_id, doc_id, text, ts)
