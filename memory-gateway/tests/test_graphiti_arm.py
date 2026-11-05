import os
from datetime import datetime, timezone

import pytest

from memory_gateway.arms.base import IngestItem, count_tokens
from memory_gateway.arms.graphiti import (
    GraphitiArm,
    current_only_filters,
    group_id_for,
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
