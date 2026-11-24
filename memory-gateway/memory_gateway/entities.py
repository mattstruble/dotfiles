"""Named-entity extraction from a recall query (Bedrock Haiku, forced tool output)."""

import asyncio
import hashlib
import logging
import time
from collections import OrderedDict
from pathlib import Path
from typing import Any

from .config import Config
from .usage import UsageRecordingClient

log = logging.getLogger(__name__)

MAX_ENTITIES = 5
CACHE_SIZE = 1000
FAILURE_TTL_S = 60.0  # negative cache per query, and global circuit duration
CIRCUIT_THRESHOLD = 3  # consecutive failures that open the circuit
TOOL_NAME = "extract_entities"
SYSTEM = (
    "Extract up to 5 named entities from the user's query that a memory search should "
    "look up: people, ticket ids (like PRJ-123), repositories, services and tools. "
    "Return names exactly as written. Return an empty list if there are none."
)
TOOL = {
    "name": TOOL_NAME,
    "description": "Report the named entities found in the query.",
    "input_schema": {
        "type": "object",
        "properties": {
            "entities": {"type": "array", "items": {"type": "string"}, "maxItems": MAX_ENTITIES}
        },
        "required": ["entities"],
    },
}


def clean_entities(raw: Any) -> list[str]:
    """Trim, drop blanks and case-insensitive duplicates, cap at MAX_ENTITIES."""
    out: list[str] = []
    seen: set[str] = set()
    for e in raw if isinstance(raw, list) else []:
        if not isinstance(e, str):
            continue
        e = e.strip()
        if e and e.lower() not in seen:
            seen.add(e.lower())
            out.append(e)
    return out[:MAX_ENTITIES]


class EntityExtractor:
    """`extract(query)` never raises: any failure or timeout yields no entities."""

    def __init__(self, config: Config, state_dir: Path, client: Any = None):
        self.config = config
        self.state_dir = Path(state_dir)
        self._client = client
        self._cache: OrderedDict[str, list[str]] = OrderedDict()
        self._failed_until: OrderedDict[str, float] = OrderedDict()
        self._circuit_until = 0.0
        self._consecutive_failures = 0

    def _get_client(self) -> Any:
        if self._client is None:
            import anthropic

            self._client = UsageRecordingClient(
                anthropic.AsyncAnthropicBedrock(aws_region=self.config.aws_region),
                self.state_dir, "gateway", "entities",
            )
        return self._client

    async def _call(self, query: str) -> list[str]:
        resp = await self._get_client().messages.create(
            model=self.config.entity_model,
            max_tokens=256,
            system=SYSTEM,
            messages=[{"role": "user", "content": query}],
            tools=[TOOL],
            tool_choice={"type": "tool", "name": TOOL_NAME},
        )
        for block in resp.content:
            if getattr(block, "type", None) == "tool_use" and block.name == TOOL_NAME:
                return clean_entities((block.input or {}).get("entities"))
        return []

    async def extract(self, query: str) -> list[str]:
        key = hashlib.sha256(query.encode()).hexdigest()
        if key in self._cache:
            self._cache.move_to_end(key)
            return list(self._cache[key])
        now = time.monotonic()
        if now < self._circuit_until or now < self._failed_until.get(key, 0.0):
            return []
        try:
            entities = await asyncio.wait_for(self._call(query), self.config.entity_timeout_s)
        except asyncio.CancelledError:
            raise
        except Exception as e:  # noqa: BLE001 - extraction is best effort
            log.warning("entity extraction failed: %s", f"{type(e).__name__}: {e}")
            self._record_failure(key)
            return []
        self._consecutive_failures = 0
        self._failed_until.pop(key, None)
        self._cache[key] = entities
        if len(self._cache) > CACHE_SIZE:
            self._cache.popitem(last=False)
        return list(entities)

    def _record_failure(self, key: str) -> None:
        """Skip this query for FAILURE_TTL_S; after CIRCUIT_THRESHOLD failures in a row
        skip all extraction, so an outage does not add the timeout to every recall."""
        now = time.monotonic()
        self._failed_until[key] = now + FAILURE_TTL_S
        self._failed_until.move_to_end(key)
        while len(self._failed_until) > CACHE_SIZE:
            self._failed_until.popitem(last=False)
        self._consecutive_failures += 1
        if self._consecutive_failures >= CIRCUIT_THRESHOLD:
            self._circuit_until = now + FAILURE_TTL_S
