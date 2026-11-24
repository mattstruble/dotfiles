"""Graphiti arm: in-process graphiti-core on embedded FalkorDB (falkordblite),
Claude on Bedrock for extraction, local fastembed embeddings."""

import asyncio
import logging
import os
import re
from datetime import datetime, timedelta, timezone
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

log = logging.getLogger(__name__)

GLOBAL_GROUP = "global"
FORGET_TOP_K = 5
NODE_PREFIX = "node:"
ENTITY_BUDGET_SHARE = 0.4  # of the recall budget, across all entities
ENTITY_CAP_TOKENS = 300  # summary + facts, per entity
ENTITY_FACT_TOKENS = 250
MIN_ENTITY_TOKENS = 10
ENTITY_DEADLINE_S = 3.0  # shared by all entity lookups in one recall

TRIVIAL_MAX_LEN = 120
_TRIVIAL_FACTS = [
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^.+? (?:is|are) (?:a|an) (?:story|subtask|spike|epic|pull request|PR|repository|package|ticket)\b",
        r"^.+? is part of .+$",
        r"^.+? is (?:related to|associated with) .+?\.?$",
        r"^.+? (?:contains|holds) the (?:code location|specification)",
    )
]
_TICKET_ID = re.compile(r"\b[A-Z][A-Z0-9]*-\d+\b")
_VERSION_OR_DATE = re.compile(
    r"\bv?\d+\.\d+|\b\d{4}-\d{1,2}(?:-\d{1,2})?\b|\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b"
    r"|\b(?:19|20)\d{2}\b|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.? \d",
    re.IGNORECASE,
)
_STALE_PLAN = re.compile(r"\bshould\b|\bwill\b|\bplans? to\b|\bnext week\b", re.IGNORECASE)
STALE_PLAN_DAYS = 14
NEAR_DUP_JACCARD = 0.8


def group_id_for(project: str | None) -> str:
    if not project:
        return GLOBAL_GROUP
    return re.sub(r"[^A-Za-z0-9_-]", "_", project)


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


def is_trivial_fact(text: str) -> bool:
    """Structural boilerplate ("X is a story", "X is part of Y") carrying no information."""
    text = text.strip()
    if len(text) >= TRIVIAL_MAX_LEN or "," in text or ";" in text:
        return False
    if _VERSION_OR_DATE.search(_TICKET_ID.sub("", text)):
        return False
    return any(rx.search(text) for rx in _TRIVIAL_FACTS)


def is_stale_plan(fact: str, valid_at: datetime | None, now: datetime) -> bool:
    if valid_at is None or not _STALE_PLAN.search(fact):
        return False
    if valid_at.tzinfo is None:
        valid_at = valid_at.replace(tzinfo=timezone.utc)
    return now - valid_at > timedelta(days=STALE_PLAN_DAYS)


def rank_facts(edges: list[Any], now: datetime | None = None) -> list[Any]:
    """Drop trivial facts; move stale future-tense facts after the rest (order kept)."""
    now = now or datetime.now(timezone.utc)
    kept = [e for e in edges if not is_trivial_fact(e.fact)]
    stale = [e for e in kept if is_stale_plan(e.fact, e.valid_at, now)]
    return [e for e in kept if e not in stale] + stale


def _fact_tokens(text: str) -> set[str]:
    return set(re.sub(r"[^\w\s]", " ", text.lower()).split())


def _jaccard(a: set[str], b: set[str]) -> float:
    return len(a & b) / len(a | b) if a | b else 1.0


def _name_words(name: str) -> list[str]:
    return re.findall(r"[\w-]+", name.lower())


def _contains_run(words: list[str], run: list[str]) -> bool:
    return any(words[i : i + len(run)] == run for i in range(len(words) - len(run) + 1))


def _truncate(text: str, max_tokens: int) -> str:
    if count_tokens(text) <= max_tokens:
        return text
    return text[: max_tokens * 4 - 1].rstrip() + "…"


class _FactCollector:
    """Turns ranked edges into Memories across several searches, deduplicating by id
    and by near-identical text."""

    def __init__(self, arm_name: str):
        self.arm_name = arm_name
        self.ids: set[str] = set()
        self._token_sets: list[set[str]] = []

    def take(self, edges: list[Any], budget_tokens: int) -> list[Memory]:
        out: list[Memory] = []
        used = 0
        for edge in rank_facts(edges):
            n = count_tokens(edge.fact)
            toks = _fact_tokens(edge.fact)
            if (
                edge.uuid in self.ids
                or used + n > budget_tokens
                or any(_jaccard(toks, t) >= NEAR_DUP_JACCARD for t in self._token_sets)
            ):
                continue
            used += n
            self.ids.add(edge.uuid)
            self._token_sets.append(toks)
            out.append(
                Memory(
                    id=edge.uuid,
                    text=edge.fact,
                    tokens=n,
                    ts=edge.valid_at,
                    arm=self.arm_name,
                    source_ref=edge.group_id,
                )
            )
        return out


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

    async def _search(
        self, project: str | None, query: str, limit: int, center_node_uuid: str | None = None
    ) -> list[Any]:
        return await self._graphiti.search(
            query,
            center_node_uuid=center_node_uuid,
            group_ids=recall_group_ids(project),
            num_results=limit,
            search_filter=current_only_filters(),
        )

    async def _search_nodes(self, project: str | None, name: str, limit: int = 5) -> list[Any]:
        from graphiti_core.search.search_config_recipes import NODE_HYBRID_SEARCH_RRF

        res = await self._graphiti.search_(
            name,
            config=NODE_HYBRID_SEARCH_RRF.model_copy(update={"limit": limit}),
            group_ids=recall_group_ids(project),
        )
        return res.nodes

    async def _find_node(self, project: str | None, name: str) -> Any | None:
        """Best EntityNode for `name`: exact name match, else the first hit whose name
        contains the entity (or vice versa) as whole words. Substrings of a word do not
        count (PRJ-12 vs PRJ-123, git vs GitHub); unrelated vector neighbours are dropped."""
        want = _name_words(name)
        nodes = await self._search_nodes(project, name)
        for n in nodes:
            if _name_words(n.name) == want:
                return n
        for n in nodes:
            have = _name_words(n.name)
            if want and have and (_contains_run(have, want) or _contains_run(want, have)):
                return n
        return None

    async def _fetch_entity(self, project: str | None, name: str) -> tuple[Any, list[Any]] | None:
        """(node, centred edges) for one entity, or None when the graph has no such node."""
        node = await self._find_node(project, name)
        if node is None:
            return None
        return node, await self._search(project, name, 10, center_node_uuid=node.uuid)

    @staticmethod
    async def _collect_entities(
        entities: list[str], tasks: list[asyncio.Future[tuple[Any, list[Any]] | None]]
    ) -> list[tuple[Any, list[Any]] | None]:
        """Wait for the entity fetches under one shared deadline. Entities that fail or
        miss the deadline come back as None; finished ones are kept."""
        try:
            if tasks:
                await asyncio.wait(tasks, timeout=ENTITY_DEADLINE_S)
        finally:
            for t in tasks:
                t.cancel()
        results: list[tuple[Any, list[Any]] | None] = []
        for name, t in zip(entities, tasks):
            if not t.done() or t.cancelled():
                log.warning("graphiti entity recall for %r timed out", name)
                results.append(None)
            elif (exc := t.exception()) is not None:
                # Entity material is a bonus; a failing lookup must not lose the main recall.
                log.warning("graphiti entity recall for %r failed: %s", name, exc)
                results.append(None)
            else:
                results.append(t.result())
        return results

    def _assemble_entities(
        self,
        entities: list[str],
        fetched: list[tuple[Any, list[Any]] | None],
        budget_tokens: int,
        facts: _FactCollector,
    ) -> list[Memory]:
        total = int(budget_tokens * ENTITY_BUDGET_SHARE)
        out: list[Memory] = []
        used = 0
        for name, hit in zip(entities, fetched):
            cap = min(ENTITY_CAP_TOKENS, total - used)
            if cap < MIN_ENTITY_TOKENS:
                break
            if hit is None:
                continue
            node, edges = hit
            if f"{NODE_PREFIX}{node.uuid}" in facts.ids:
                continue
            part: list[Memory] = []
            spent = 0
            summary = (node.summary or "").strip()
            if summary:
                text = _truncate(f"{node.name}: {summary}", cap)
                ref = f"{NODE_PREFIX}{node.uuid}"
                spent = count_tokens(text)
                part.append(Memory(ref, text, spent, node.created_at, self.name, source_ref=ref))
            facts.ids.add(f"{NODE_PREFIX}{node.uuid}")
            part += facts.take(edges, min(ENTITY_FACT_TOKENS, cap - spent))
            used += sum(m.tokens for m in part)
            out += part
        return out

    async def recall(
        self,
        project: str | None,
        query: str,
        budget_tokens: int,
        entities: list[str] | None = None,
    ) -> list[Memory]:
        entities = entities or []
        tasks = [asyncio.ensure_future(self._fetch_entity(project, n)) for n in entities]
        try:
            fetched, main = await asyncio.gather(
                self._collect_entities(entities, tasks), self._search(project, query, 20)
            )
        finally:
            for t in tasks:  # no-op once finished; stops lookups if the main search fails
                t.cancel()
        facts = _FactCollector(self.name)
        out = self._assemble_entities(entities, fetched, budget_tokens, facts)
        remaining = budget_tokens - sum(m.tokens for m in out)
        return out + facts.take(main, remaining)

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

    async def _node_source(self, uuid: str) -> SourceRecord | None:
        from graphiti_core.nodes import EntityNode

        for group in await self._graph_names():
            try:
                node = await EntityNode.get_by_uuid(self._graphiti.driver.clone(group), uuid)
            except Exception:  # noqa: BLE001 - not in this graph
                continue
            ref = f"{NODE_PREFIX}{uuid}"
            return SourceRecord(
                memory_id=ref, source_ref=ref, text=node.summary, ts=node.created_at
            )
        return None

    async def source(self, memory_id: str) -> SourceRecord | None:
        from graphiti_core.edges import EntityEdge
        from graphiti_core.nodes import EpisodicNode

        if memory_id.startswith(NODE_PREFIX):
            return await self._node_source(memory_id[len(NODE_PREFIX):])
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
