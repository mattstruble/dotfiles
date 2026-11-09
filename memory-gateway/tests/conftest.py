import asyncio
from datetime import datetime, timezone

import pytest

from memory_gateway.arms.base import IngestItem, Memory, count_tokens
from memory_gateway.config import Config


class FakeArm:
    def __init__(self, name="fake", fail_ingest=0, recall_delay=0.0):
        self.name = name
        self.fail_ingest = fail_ingest
        self.recall_delay = recall_delay
        self.ingested: list[IngestItem] = []
        self.recall_texts: list[str] = ["alpha " * 8, "beta " * 8, "gamma " * 8]

    async def start(self): ...

    async def health(self):
        return "ok"

    async def ingest(self, item):
        if self.fail_ingest > 0:
            self.fail_ingest -= 1
            raise RuntimeError("arm down")
        self.ingested.append(item)

    async def recall(self, project, query, budget_tokens):
        await asyncio.sleep(self.recall_delay)
        return [
            Memory(f"{self.name}-{i}", t, count_tokens(t), None, self.name, None)
            for i, t in enumerate(self.recall_texts)
        ]

    async def forget(self, project, text, reason):
        return [f"{self.name}-0"]


def make_item(text="hi", session="s1", source="session"):
    return IngestItem(
        project="p",
        session_id=session,
        source=source,
        timestamp=datetime(2025, 1, 1, tzinfo=timezone.utc),
        text=text,
    )


@pytest.fixture
def config(tmp_path):
    return Config(state_dir=str(tmp_path), arm_timeout_s=0.5)
