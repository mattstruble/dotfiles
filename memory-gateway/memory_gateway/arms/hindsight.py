from datetime import datetime
from pathlib import Path

import httpx

from ..config import Config
from .base import IngestItem, Memory, count_tokens


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

    async def _ensure_bank(self) -> None:
        r = await self.client.get(f"{self._bank_path}/profile")
        if r.status_code == 404:
            r = await self.client.put(self._bank_path, json={"name": self.bank})
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
        entry: dict = {
            "content": item.text,
            "timestamp": item.timestamp.isoformat(),
            "context": item.source,
            "document_id": item.doc_id or f"session:{item.session_id}",
        }
        if item.source == "session":
            entry["update_mode"] = "append"
        if item.project:
            entry["tags"] = [f"project:{item.project}"]
        await self._post(
            f"{self._bank_path}/memories", {"items": [entry], "async": True}
        )

    async def _recall(
        self, project: str | None, query: str, max_tokens: int
    ) -> list[dict]:
        payload: dict = {
            "query": query,
            "max_tokens": max_tokens,
            "prefer_observations": True,
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
