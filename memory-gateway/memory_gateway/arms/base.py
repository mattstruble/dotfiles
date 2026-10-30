import math
from dataclasses import dataclass
from datetime import datetime
from typing import Literal, Protocol


def count_tokens(text: str) -> int:
    return math.ceil(len(text) / 4)


@dataclass
class IngestItem:
    project: str | None
    session_id: str
    source: Literal["session", "seed", "retain"]
    timestamp: datetime
    text: str
    doc_id: str | None = None


@dataclass
class Memory:
    id: str
    text: str
    tokens: int
    ts: datetime | None
    arm: str
    source_ref: str | None = None


class Arm(Protocol):
    name: str

    async def start(self) -> None: ...

    async def health(self) -> str:
        """'ok' or 'error: ...'"""
        ...

    async def ingest(self, item: IngestItem) -> None: ...

    async def recall(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        """Current facts only, project + global, total tokens <= budget."""
        ...

    async def forget(self, project: str | None, text: str, reason: str) -> list[str]:
        """Mark matching facts superseded (never delete); return ids."""
        ...
