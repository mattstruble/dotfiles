import asyncio
import os
import time
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from memory_gateway.arms import graphiti as graphiti_mod
from memory_gateway.arms.base import IngestItem, count_tokens
from memory_gateway.arms.graphiti import (
    GraphitiArm,
    _FactCollector,
    current_only_filters,
    group_id_for,
    is_stale_plan,
    is_trivial_fact,
    rank_facts,
    recall_group_ids,
)

live = pytest.mark.skipif(
    os.environ.get("MEMORY_GATEWAY_LIVE") != "1", reason="needs MEMORY_GATEWAY_LIVE=1"
)
VEC = [1.0] + [0.0] * 383
FACT_TEA = "alice likes tea " * 3
FACT_VIM = "alice uses vim " * 3
T = datetime(2025, 1, 1, tzinfo=timezone.utc)


def fake_embedder():
    from graphiti_core.embedder.client import EmbedderClient

    class FakeEmbedder(EmbedderClient):
        async def create(self, input_data):
            return VEC

        async def create_batch(self, input_data_list):
            return [VEC for _ in input_data_list]

    return FakeEmbedder()


def fake_llm():
    """Real client wrapper around a dummy SDK object; never called (edges are written directly)."""
    from graphiti_core.llm_client.anthropic_client import AnthropicClient
    from graphiti_core.llm_client.config import LLMConfig

    return AnthropicClient(config=LLMConfig(model="m", small_model="m"), client=object())


def test_group_id_mapping():
    assert group_id_for("proj") == "proj"
    assert group_id_for(None) == "global"


def test_group_id_sanitised():
    assert group_id_for("ml.aip-bot") == "ml_aip-bot"
    assert group_id_for("a/b c") == "a_b_c"
    assert group_id_for("café") == "caf_"
    assert recall_group_ids("ml.aip-bot") == ["ml_aip-bot", "global"]
    assert recall_group_ids("proj") == ["proj", "global"]
    assert recall_group_ids(None) == ["global"]


def test_current_only_filter():
    f = current_only_filters()
    for field in (f.expired_at, f.invalid_at):
        assert len(field) == 1 and len(field[0]) == 1
        assert field[0][0].comparison_operator.name == "is_null"
    assert f.valid_at is None


def make_arm(config, tmp_path):
    return GraphitiArm(config, tmp_path, llm_client=fake_llm(), embedder=fake_embedder())


async def add_edge(arm, group, fact):
    from graphiti_core.edges import EntityEdge
    from graphiti_core.nodes import EntityNode

    driver = arm._graphiti.driver.clone(group)
    a = EntityNode(name="a", group_id=group, name_embedding=VEC)
    b = EntityNode(name="b", group_id=group, name_embedding=VEC)
    e = EntityEdge(
        group_id=group,
        source_node_uuid=a.uuid,
        target_node_uuid=b.uuid,
        created_at=T,
        name="REL",
        fact=fact,
        fact_embedding=VEC,
        valid_at=T,
    )
    await a.save(driver)
    await b.save(driver)
    await e.save(driver)
    return e


async def test_start_creates_db_and_health(config, tmp_path):
    arm = make_arm(config, tmp_path)
    assert (await arm.health()).startswith("error")

    await arm.start()

    assert await arm.health() == "ok"
    assert any((tmp_path / "graphiti").iterdir())


async def test_recall_scopes_to_project_and_global(config, tmp_path):
    arm = make_arm(config, tmp_path)
    await arm.start()
    await add_edge(arm, "proj", FACT_TEA)
    await add_edge(arm, "global", FACT_VIM)
    await add_edge(arm, "other", "alice hidden fact")

    mems = await arm.recall("proj", "alice", 10_000)

    assert {m.text for m in mems} == {FACT_TEA, FACT_VIM}
    assert all(m.ts == T and m.arm == "graphiti" for m in mems)


async def test_recall_respects_budget(config, tmp_path):
    arm = make_arm(config, tmp_path)
    await arm.start()
    await add_edge(arm, "proj", FACT_TEA)
    await add_edge(arm, "proj", FACT_VIM)
    budget = count_tokens(FACT_TEA)

    mems = await arm.recall("proj", "alice", budget)

    assert len(mems) == 1 and sum(m.tokens for m in mems) <= budget


async def test_forget_invalidates_without_deleting(config, tmp_path):
    arm = make_arm(config, tmp_path)
    await arm.start()
    edge = await add_edge(arm, "proj", FACT_TEA)

    ids = await arm.forget("proj", "alice likes tea", "test")

    assert ids == [edge.uuid]
    assert await arm.recall("proj", "alice", 10_000) == []
    rows, _, _ = await arm._graphiti.driver.clone("proj").execute_query(
        "MATCH ()-[e:RELATES_TO {uuid: $u}]->() "
        "RETURN e.invalid_at AS i, e.expired_at AS x",
        u=edge.uuid,
    )
    assert rows[0]["i"] and rows[0]["x"]


async def test_history_returns_superseded_only(config, tmp_path):
    arm = make_arm(config, tmp_path)
    await arm.start()
    old = await add_edge(arm, "proj", FACT_TEA)
    await add_edge(arm, "proj", FACT_VIM)
    await arm._graphiti.driver.clone("proj").execute_query(
        "MATCH ()-[e:RELATES_TO {uuid: $u}]->() SET e.invalid_at = $t",
        u=old.uuid,
        t=datetime(2025, 2, 3, tzinfo=timezone.utc),
    )

    got = await arm.history("proj", "alice", 10_000)

    assert [m.id for m in got] == [old.uuid]
    assert got[0].text.startswith("[superseded 2025-02-03] ") and FACT_TEA in got[0].text
    assert got[0].tokens == count_tokens(got[0].text)
    assert await arm.history("proj", "alice", 1) == []


async def test_source_returns_latest_episode(config, tmp_path):
    from graphiti_core.nodes import EpisodicNode, EpisodeType

    arm = make_arm(config, tmp_path)
    await arm.start()
    edge = await add_edge(arm, "proj", FACT_TEA)
    driver = arm._graphiti.driver.clone("proj")
    eps = []
    for day, text in [(1, "first"), (5, "second")]:
        ep = EpisodicNode(
            name=f"ep{day}",
            group_id="proj",
            source=EpisodeType.text,
            source_description="seed",
            content=text,
            valid_at=datetime(2025, 1, day, tzinfo=timezone.utc),
        )
        await ep.save(driver)
        eps.append(ep.uuid)
    await driver.execute_query(
        "MATCH ()-[e:RELATES_TO {uuid: $u}]->() SET e.episodes = $eps",
        u=edge.uuid,
        eps=eps,
    )

    rec = await arm.source(edge.uuid)

    assert rec.text == "second" and rec.source_ref == "ep5"
    assert rec.ts == datetime(2025, 1, 5, tzinfo=timezone.utc)
    assert await arm.source("missing") is None


async def test_source_none_without_episodes(config, tmp_path):
    arm = make_arm(config, tmp_path)
    await arm.start()
    edge = await add_edge(arm, "proj", FACT_TEA)
    assert await arm.source(edge.uuid) is None


@live
async def test_live_supersession(config, tmp_path):
    arm = GraphitiArm(config, tmp_path)
    await arm.start()
    episodes = [
        (1, "Alice lives in Paris."),
        (20, "Alice moved out of Paris; she now lives in Berlin."),
    ]
    for day, text in episodes:
        ts = datetime(2025, 1, day, tzinfo=timezone.utc)
        await arm.ingest(IngestItem("proj", "s1", "session", ts, text))

    facts = " ".join(
        m.text for m in await arm.recall("proj", "Where does Alice live?", 1000)
    )

    assert "Berlin" in facts and "Paris" not in facts

    hist = await arm.history("proj", "Where does Alice live?", 1000)
    assert any("Paris" in m.text and m.text.startswith("[superseded ") for m in hist)
    src = await arm.source(hist[0].id)
    assert src is not None and src.text in {t for _, t in episodes}


# --- entity-aware recall, noise filters ---------------------------------------------

NOW = datetime.now(timezone.utc)


def edge(uuid, fact, valid_at=T, group="proj"):
    return SimpleNamespace(uuid=uuid, fact=fact, valid_at=valid_at, group_id=group)


def node(uuid, name, summary, created=T):
    return SimpleNamespace(uuid=uuid, name=name, summary=summary, created_at=created)


def fake_arm(config, tmp_path, nodes=None, edges=None, main=None):
    """Arm with search stubbed: nodes {name: node}, edges {center uuid: [edge]}, main [edge]."""
    arm = make_arm(config, tmp_path)
    calls = []

    async def search_nodes(project, name, limit=5):
        return [nodes[name]] if name in (nodes or {}) else []

    async def search(project, query, limit, center_node_uuid=None):
        calls.append((query, center_node_uuid))
        if center_node_uuid is not None:
            return (edges or {}).get(center_node_uuid, [])
        return main or []

    arm._search_nodes = search_nodes
    arm._search = search
    arm.calls = calls
    return arm


def test_stale_plan_needs_whole_word_and_tolerates_naive_datetimes():
    old = NOW - timedelta(days=30)
    assert not is_stale_plan("the willing helper", old, NOW)
    assert is_stale_plan("we will go", old.replace(tzinfo=None), NOW)


def test_near_duplicates_collapse():
    c = _FactCollector("graphiti")
    first = c.take(
        [
            edge("1", "Alice prefers the vim editor for all work"),
            edge("2", "alice prefers the vim editor, for all work!"),
            edge("3", "Alice prefers the emacs editor for all work"),  # 6/8 = 0.75 < 0.8
            edge("4", "Alice prefers the vim editor for all work today"),  # 8/9 >= 0.8
        ],
        1000,
    )
    assert [m.id for m in first] == ["1", "3"]
    # collapse also spans later calls
    assert c.take([edge("5", "alice prefers the vim editor for all work")], 1000) == []


async def test_entity_summary_first_then_centred_facts_then_main(config, tmp_path):
    n = node("n1", "Alice", "Staff engineer on platform.")
    arm = fake_arm(
        config, tmp_path,
        nodes={"Alice": n},
        edges={"n1": [edge("e1", "alice owns the gateway")]},
        main=[edge("m1", "bob uses emacs")],
    )

    mems = await arm.recall("proj", "who is alice", 1000, entities=["Alice", "Unknown"])

    assert [m.id for m in mems] == ["node:n1", "e1", "m1"]
    first = mems[0]
    assert first.text == "Alice: Staff engineer on platform."
    assert first.source_ref == "node:n1" and first.ts == T and first.arm == "graphiti"
    assert first.tokens == count_tokens(first.text)
    assert arm.calls == [("Alice", "n1"), ("who is alice", None)]


async def test_entity_without_summary_still_gets_facts(config, tmp_path):
    arm = fake_arm(
        config, tmp_path,
        nodes={"Alice": node("n1", "Alice", "  ")},
        edges={"n1": [edge("e1", "alice owns the gateway")]},
    )

    mems = await arm.recall("proj", "q", 1000, entities=["Alice"])

    assert [m.id for m in mems] == ["e1"]


async def test_entity_material_deduped_against_main_and_other_entities(config, tmp_path):
    shared = edge("e1", "alice and bob own the gateway")
    arm = fake_arm(
        config, tmp_path,
        nodes={"Alice": node("n1", "Alice", "a"), "Al": node("n1", "Alice", "a"),
               "Bob": node("n2", "Bob", "b")},
        edges={"n1": [shared], "n2": [shared, edge("e2", "bob uses emacs")]},
        main=[shared, edge("m1", "carol likes tea")],
    )

    mems = await arm.recall("proj", "q", 1000, entities=["Alice", "Al", "Bob"])

    assert [m.id for m in mems] == ["node:n1", "e1", "node:n2", "e2", "m1"]


async def test_per_entity_cap_limits_summary_and_facts(config, tmp_path):
    facts = [edge(f"e{i}", f"fact number {i} " + "pad " * 20) for i in range(20)]
    arm = fake_arm(
        config, tmp_path,
        nodes={"Alice": node("n1", "Alice", "word " * 400)},  # 500-token summary
        edges={"n1": facts},
    )

    mems = await arm.recall("proj", "q", 100_000, entities=["Alice"])

    assert mems[0].id == "node:n1" and sum(m.tokens for m in mems) <= 300

    arm = fake_arm(
        config, tmp_path,
        nodes={"Alice": node("n1", "Alice", "short summary")},
        edges={"n1": facts},
    )
    mems = await arm.recall("proj", "q", 100_000, entities=["Alice"])

    assert len(mems) > 2 and sum(m.tokens for m in mems[1:]) <= 250


async def test_total_entity_cap_is_forty_percent_of_budget(config, tmp_path):
    nodes = {f"E{i}": node(f"n{i}", f"E{i}", "summary " * 10) for i in range(3)}
    edges = {
        f"n{i}": [edge(f"e{i}{j}", f"entity fact {i} {j} " + "x" * 80) for j in range(8)]
        for i in range(3)
    }
    main = [edge(f"m{i}", f"main fact {i} " + "y" * 80) for i in range(30)]
    arm = fake_arm(config, tmp_path, nodes=nodes, edges=edges, main=main)

    mems = await arm.recall("proj", "q", 500, entities=["E0", "E1", "E2"])

    entity_tokens = sum(m.tokens for m in mems if not m.id.startswith("m"))
    assert mems[0].id == "node:n0"
    assert 100 < entity_tokens <= 200
    assert sum(m.tokens for m in mems) <= 500
    assert any(m.id.startswith("m") for m in mems)


async def test_entity_search_failure_falls_back_to_main(config, tmp_path):
    arm = fake_arm(config, tmp_path, main=[edge("m1", "carol likes tea")])

    async def boom(*a, **k):
        raise RuntimeError("db down")

    arm._search_nodes = boom

    assert [m.id for m in await arm.recall("proj", "q", 1000, entities=["Alice"])] == ["m1"]


async def test_find_node_prefers_exact_then_containing_name(config, tmp_path):
    arm = make_arm(config, tmp_path)

    async def search_nodes(project, name, limit=5):
        return [node("1", "Unrelated", "x"), node("2", "Alice Smith", "y"), node("3", "alice", "z")]

    arm._search_nodes = search_nodes

    assert (await arm._find_node("proj", "Alice")).uuid == "3"
    assert (await arm._find_node("proj", "smith")).uuid == "2"
    assert await arm._find_node("proj", "Zed") is None


async def test_source_for_node_ids(config, tmp_path):
    from graphiti_core.nodes import EntityNode

    arm = make_arm(config, tmp_path)
    await arm.start()
    driver = arm._graphiti.driver.clone("proj")
    n = EntityNode(name="Alice", group_id="proj", name_embedding=VEC, summary="Alice is an SRE.",
                   created_at=T)
    await n.save(driver)

    rec = await arm.source(f"node:{n.uuid}")

    assert rec.text == "Alice is an SRE." and rec.source_ref == f"node:{n.uuid}"
    assert rec.memory_id == f"node:{n.uuid}" and rec.ts == T
    assert await arm.source("node:missing") is None


async def test_entity_recall_against_real_graph(config, tmp_path):
    from graphiti_core.nodes import EntityNode

    arm = make_arm(config, tmp_path)
    await arm.start()
    await add_edge(arm, "proj", FACT_TEA)
    driver = arm._graphiti.driver.clone("proj")
    n = EntityNode(name="Alice", group_id="proj", name_embedding=VEC, summary="Alice drinks tea.")
    await n.save(driver)

    mems = await arm.recall("proj", "tea", 10_000, entities=["Alice"])

    assert mems[0].id == f"node:{n.uuid}" and mems[0].text == "Alice: Alice drinks tea."
    assert FACT_TEA in {m.text for m in mems}


# --- concurrent, bounded entity recall ------------------------------------------------

def slow_arm(config, tmp_path, nodes, edges, main, delays=None, errors=()):
    """Arm whose searches sleep delays[name or query] and whose lookups may raise."""
    arm = make_arm(config, tmp_path)
    delays = delays or {}

    async def search_nodes(project, name, limit=5):
        await asyncio.sleep(delays.get(name, 0))
        if name in errors:
            raise RuntimeError("graph down")
        return [nodes[name]] if name in nodes else []

    async def search(project, query, limit, center_node_uuid=None):
        await asyncio.sleep(delays.get(query, 0))
        if center_node_uuid is not None:
            return edges.get(center_node_uuid, [])
        return main

    arm._search_nodes = search_nodes
    arm._search = search
    return arm


async def test_entities_and_main_search_run_concurrently(config, tmp_path):
    names = ["a", "b", "c"]
    nodes = {n: node(n, n, f"{n} summary") for n in names}
    delays = {n: 0.2 for n in names} | {"q": 0.2}
    arm = slow_arm(config, tmp_path, nodes, {}, [edge("m", "main fact")], delays)

    t0 = time.monotonic()
    out = await arm.recall("proj", "q", 1000, entities=names)
    elapsed = time.monotonic() - t0

    assert elapsed < 0.6  # sequential would take about 1.4 s
    assert [m.id for m in out] == ["node:a", "node:b", "node:c", "m"]


async def test_entity_deadline_keeps_main_and_finished_entities(config, tmp_path, monkeypatch):
    monkeypatch.setattr(graphiti_mod, "ENTITY_DEADLINE_S", 0.1)
    nodes = {"fast": node("f", "fast", "fast summary"), "slow": node("s", "slow", "slow summary")}
    arm = slow_arm(config, tmp_path, nodes, {}, [edge("m", "main fact")], {"slow": 5.0})

    t0 = time.monotonic()
    out = await arm.recall("proj", "q", 1000, entities=["slow", "fast"])

    assert time.monotonic() - t0 < 1.0
    assert [m.id for m in out] == ["node:f", "m"]


async def test_entity_exception_is_skipped(config, tmp_path):
    nodes = {"bad": node("b", "bad", "x"), "ok": node("o", "ok", "ok summary")}
    arm = slow_arm(config, tmp_path, nodes, {}, [edge("m", "main fact")], errors={"bad"})

    out = await arm.recall("proj", "q", 1000, entities=["bad", "ok"])

    assert [m.id for m in out] == ["node:o", "m"]


async def test_assembly_follows_entity_order_not_completion_order(config, tmp_path):
    nodes = {n: node(n, n, "s " * 50) for n in ("a", "b", "c")}
    edges = {
        "a": [edge("e1", "a likes tea"), edge("shared", "shared fact one")],
        "b": [edge("shared", "shared fact one"), edge("e2", "b likes coffee")],
        "c": [edge("e3", "c likes water")],
    }
    main = [edge("shared", "shared fact one"), edge("m1", "main only fact")]
    arm = slow_arm(config, tmp_path, nodes, edges, main, {"a": 0.15, "b": 0.1, "c": 0.0})
    ref = fake_arm(config, tmp_path, nodes, edges, main)

    out = await arm.recall("proj", "q", 1000, entities=["a", "b", "c"])
    expected = await ref.recall("proj", "q", 1000, entities=["a", "b", "c"])

    assert [(m.id, m.text) for m in out] == [(m.id, m.text) for m in expected]
    assert [m.id for m in out] == ["node:a", "e1", "shared", "node:b", "e2", "node:c", "e3", "m1"]
