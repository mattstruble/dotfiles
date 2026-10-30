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


@dataclass
class SourceRecord:
    """Raw input text (episode/document/note version) a fact was extracted from."""

    memory_id: str
    source_ref: str | None
    text: str
    ts: datetime | None


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

    # Optional lineage methods. Arms may omit them; the gateway looks them up with
    # getattr and reports "unsupported" when absent.
    #
    # async def history(
    #     self, project: str | None, query: str, budget_tokens: int
    # ) -> list[Memory]:
    #     """Facts relevant to `query` that are superseded/invalidated/no longer
    #     current (the complement of recall), most recent first."""
    #
    # async def source(self, memory_id: str) -> SourceRecord | None:
    #     """Raw input text the fact `memory_id` was extracted from, or None."""
