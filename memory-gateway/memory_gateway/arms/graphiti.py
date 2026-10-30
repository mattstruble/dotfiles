"""Graphiti arm: in-process graphiti-core on embedded FalkorDB (falkordblite),
Claude on Bedrock for extraction, local fastembed embeddings."""

import asyncio
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ..config import Config
from ..usage import UsageRecordingClient
from .base import IngestItem, Memory, SourceRecord, count_tokens

# Must be set before graphiti_core is imported (telemetry, module-level constants).
os.environ["GRAPHITI_TELEMETRY_ENABLED"] = "false"
EMBED_MODEL = "BAAI/bge-small-en-v1.5"
EMBED_DIM = 384
os.environ["EMBEDDING_DIM"] = str(EMBED_DIM)

GLOBAL_GROUP = "global"
FORGET_TOP_K = 5


def group_id_for(project: str | None) -> str:
    return project or GLOBAL_GROUP


def recall_group_ids(project: str | None) -> list[str]:
    group = group_id_for(project)
    return [GLOBAL_GROUP] if group == GLOBAL_GROUP else [group, GLOBAL_GROUP]


def current_only_filters() -> Any:
    """Exclude edges that graphiti (or forget) has invalidated or expired."""
    from graphiti_core.search.search_filters import (
        ComparisonOperator,
        DateFilter,
        SearchFilters,
    )

    null = [[DateFilter(comparison_operator=ComparisonOperator.is_null)]]
    return SearchFilters(expired_at=null, invalid_at=null)


def superseded_filters() -> list[Any]:
    """Two filters (graphiti ANDs across fields, so OR is done by merging results):
    edges with invalid_at set, and edges with expired_at set."""
    from graphiti_core.search.search_filters import (
        ComparisonOperator,
        DateFilter,
        SearchFilters,
    )

    not_null = [[DateFilter(comparison_operator=ComparisonOperator.is_not_null)]]
    return [SearchFilters(invalid_at=not_null), SearchFilters(expired_at=not_null)]


def _make_embedder() -> Any:
    from graphiti_core.embedder.client import EmbedderClient

    class FastEmbedEmbedder(EmbedderClient):
        def __init__(self) -> None:
            self._model: Any = None

        def _embed(self, texts: list[str]) -> list[list[float]]:
            if self._model is None:
                from fastembed import TextEmbedding

                self._model = TextEmbedding(EMBED_MODEL)
            return [[float(x) for x in v] for v in self._model.embed(texts)]

        async def create(self, input_data: Any) -> list[float]:
            texts = [input_data] if isinstance(input_data, str) else list(input_data)
            out = await asyncio.get_running_loop().run_in_executor(
                None, self._embed, [str(t) for t in texts]
            )
            return out[0]

        async def create_batch(self, input_data_list: list[str]) -> list[list[float]]:
            return await asyncio.get_running_loop().run_in_executor(
                None, self._embed, list(input_data_list)
            )

    return FastEmbedEmbedder()


def _make_cross_encoder() -> Any:
    from graphiti_core.cross_encoder.client import CrossEncoderClient

    class PassthroughReranker(CrossEncoderClient):
        """Keeps input order; avoids an OpenAI key or a local reranker model."""

        async def rank(self, query: str, passages: list[str]) -> list[tuple[str, float]]:
            n = len(passages)
            return [(p, float(n - i)) for i, p in enumerate(passages)]

    return PassthroughReranker()


def _make_llm(config: Config, state_dir: Path) -> Any:
    import anthropic
    from graphiti_core.llm_client.anthropic_client import AnthropicClient
    from graphiti_core.llm_client.config import LLMConfig

    return AnthropicClient(
        config=LLMConfig(model=config.bedrock_model, small_model=config.bedrock_model),
        client=UsageRecordingClient(
            anthropic.AsyncAnthropicBedrock(aws_region=config.aws_region),
            state_dir, "graphiti", "graphiti",
        ),
    )


class GraphitiArm:
    name = "graphiti"

    def __init__(
        self,
        config: Config,
        state_dir: Path,
        llm_client: Any = None,
        embedder: Any = None,
        cross_encoder: Any = None,
    ):
        self.config = config
        self.state_dir = Path(state_dir)
        self.db_path = self.state_dir / "graphiti" / "graph.db"
        self._llm_client = llm_client
        self._embedder = embedder
        self._cross_encoder = cross_encoder
        self._graphiti: Any = None
        self._lock = asyncio.Lock()
        self._error: str | None = "not started"

    async def start(self) -> None:
        try:
            await self._start()
            self._error = None
        except Exception as e:
            # Surface the failure through health() and still let the caller see it.
            self._error = str(e) or type(e).__name__
            raise

    async def _start(self) -> None:
        from redislite.async_falkordb_client import AsyncFalkorDB

        from graphiti_core import Graphiti
        from graphiti_core.driver.falkordb_driver import FalkorDriver

        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        driver = FalkorDriver(falkor_db=AsyncFalkorDB(str(self.db_path)))
        self._graphiti = Graphiti(
            graph_driver=driver,
            llm_client=self._llm_client or _make_llm(self.config, self.state_dir),
            embedder=self._embedder or _make_embedder(),
            cross_encoder=self._cross_encoder or _make_cross_encoder(),
        )
        await self._graphiti.build_indices_and_constraints()

    async def health(self) -> str:
        return "ok" if self._error is None else f"error: {self._error}"

    async def ingest(self, item: IngestItem) -> None:
        from graphiti_core.nodes import EpisodeType

        ts = item.timestamp
        async with self._lock:
            await self._graphiti.add_episode(
                name=f"{item.source}:{item.session_id}:{ts.isoformat()}",
                episode_body=item.text,
                source_description=item.source,
                reference_time=ts,
                source=EpisodeType.text,
                group_id=group_id_for(item.project),
            )

    async def _search(self, project: str | None, query: str, limit: int) -> list[Any]:
        return await self._graphiti.search(
            query,
            group_ids=recall_group_ids(project),
            num_results=limit,
            search_filter=current_only_filters(),
        )

    async def recall(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        out: list[Memory] = []
        used = 0
        for edge in await self._search(project, query, 20):
            n = count_tokens(edge.fact)
            if used + n > budget_tokens:
                continue
            used += n
            out.append(
                Memory(
                    id=edge.uuid,
                    text=edge.fact,
                    tokens=n,
                    ts=edge.valid_at,
                    arm=self.name,
                    source_ref=edge.group_id,
                )
            )
        return out

    async def forget(self, project: str | None, text: str, reason: str) -> list[str]:
        now = datetime.now(timezone.utc)
        ids: list[str] = []
        async with self._lock:
            for edge in (await self._search(project, text, FORGET_TOP_K))[:FORGET_TOP_K]:
                driver = self._graphiti.driver.clone(edge.group_id)
                await driver.execute_query(
                    "MATCH ()-[e:RELATES_TO {uuid: $uuid}]->() "
                    "SET e.invalid_at = $now, e.expired_at = $now",
                    uuid=edge.uuid,
                    now=now,
                )
                ids.append(edge.uuid)
        return ids

    async def history(
        self, project: str | None, query: str, budget_tokens: int
    ) -> list[Memory]:
        edges: dict[str, Any] = {}
        for f in superseded_filters():
            for edge in await self._graphiti.search(
                query,
                group_ids=recall_group_ids(project),
                num_results=20,
                search_filter=f,
            ):
                edges.setdefault(edge.uuid, edge)

        def when(e: Any) -> datetime:
            return e.invalid_at or e.expired_at

        out: list[Memory] = []
        used = 0
        for edge in sorted(edges.values(), key=when, reverse=True):
            text = f"[superseded {when(edge).date().isoformat()}] {edge.fact}"
            n = count_tokens(text)
            if used + n > budget_tokens:
                continue
            used += n
            out.append(
                Memory(
                    id=edge.uuid,
                    text=text,
                    tokens=n,
                    ts=when(edge),
                    arm=self.name,
                    source_ref=edge.group_id,
                )
            )
        return out

    async def _graph_names(self) -> list[str]:
        try:
            names = await self._graphiti.driver.client.list_graphs()
        except Exception:
            names = []
        return list(dict.fromkeys([*names, GLOBAL_GROUP]))

    async def source(self, memory_id: str) -> SourceRecord | None:
        from graphiti_core.edges import EntityEdge
        from graphiti_core.nodes import EpisodicNode

        for group in await self._graph_names():
            driver = self._graphiti.driver.clone(group)
            try:
                edge = await EntityEdge.get_by_uuid(driver, memory_id)
            except Exception:
                continue
            if not edge.episodes:
                return None
            nodes = await EpisodicNode.get_by_uuids(driver, list(edge.episodes))
            if not nodes:
                return None
            ep = max(nodes, key=lambda n: n.valid_at)
            return SourceRecord(
                memory_id=memory_id, source_ref=ep.name, text=ep.content, ts=ep.valid_at
            )
        return None
