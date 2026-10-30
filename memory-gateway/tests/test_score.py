import json
import sqlite3

import httpx
import pytest
import respx

from memory_gateway.config import Config
from memory_gateway.eval import score

GW = "http://gw.test"


@pytest.fixture(autouse=True)
def eval_env(tmp_path, monkeypatch):
    monkeypatch.setenv("MEMORY_GATEWAY_EVAL_DIR", str(tmp_path / "eval"))
    return tmp_path / "eval"


class FakeJudge:
    """leak if memories contain 'STALE'; covered if the note's first word appears in memories."""

    def __init__(self):
        self.calls = 0
        self.last_usage = (10, 2)

    async def __call__(self, kind, payload):
        self.calls += 1
        if kind == "stale":
            ms = " ".join(payload["memories"])
            return {"leak": "STALE" in ms, "current_present": "CURRENT" in ms}
        if kind == "coverage":
            key = payload["note"].split()[0]
            return {"covered": any(key in m for m in payload["memories"])}
        if kind == "pick_current":
            for i, m in enumerate(payload["memories"]):
                if "CURRENT" in m:
                    return {"found": True, "index": i}
            return {"found": False, "index": -1}
        if kind == "supports":
            return {"supported": "BACKED" in payload["source"]}
        if kind == "states_fact":
            return {"stated": any("STALE" in m for m in payload["memories"])}
        return {"relevant": "junk" not in payload["memory"]}


def mock_gateway(mocks, arms=("a", "b")):
    respx.get(f"{GW}/health").mock(return_value=httpx.Response(200, json={"ok": True, "arms": {a: "ok" for a in arms}}))

    def recall(request):
        body = json.loads(request.content)
        arm = body["arms"][0]
        assert body["budget_tokens"] == 2000
        texts = mocks[arm].get(body["query"], [])
        return httpx.Response(200, json={"results": {arm: [{"id": "x", "text": t, "tokens": 5} for t in texts]}, "errors": {}})

    respx.post(f"{GW}/recall").mock(side_effect=recall)


PAIRS = [{"id": f"p{i}", "project": None, "question": f"q{i}", "stale_fact": "s", "current_fact": "c"} for i in range(3)]


@respx.mock
async def test_stale_gate_threshold_and_cache(eval_env):
    mock_gateway({"a": {"q0": ["STALE x"], "q1": ["CURRENT"], "q2": ["CURRENT"]},
                  "b": {"q0": ["STALE"], "q1": ["STALE"], "q2": []}})
    j = FakeJudge()
    cj = score.CachedJudge(j)
    res = await score.stale_gate(GW, cj, PAIRS)
    assert res["a"]["leaks"] == 1 and res["a"]["pass"] and res["a"]["leak_ids"] == ["p0"]
    assert res["a"]["current_present_rate"] == pytest.approx(2 / 3)
    assert res["b"]["leaks"] == 2 and not res["b"]["pass"]
    calls, hits = j.calls, cj.hits
    await score.stale_gate(GW, cj, PAIRS)
    assert j.calls == calls and cj.hits - hits == 5  # 5 non-empty recalls, all cached
    assert cj.spend()["judgements"] == calls
    assert (eval_env / "judge-cache.sqlite").exists()


@respx.mock
async def test_stale_gate_recall_error_fails_arm():
    respx.get(f"{GW}/health").mock(return_value=httpx.Response(200, json={"arms": {"a": "ok"}}))
    respx.post(f"{GW}/recall").mock(return_value=httpx.Response(200, json={"results": {}, "errors": {"a": "boom"}}))
    res = await score.stale_gate(GW, FakeJudge(), PAIRS[:1])
    assert res["a"]["errors"] == 1 and not res["a"]["pass"]


def write_session(sessions, wiki):
    d = sessions / "proj"
    d.mkdir(parents=True)
    f = d / "s1.jsonl"
    note = wiki / "topics" / "alpha.md"
    note.parent.mkdir(parents=True)
    note.write_text("alpha fact is 42")
    (wiki / "topics" / "beta.md").write_text("beta fact is 7")
    rows = [
        {"type": "custom_message", "customType": "knowledge-base", "content": "## KB\n- [[topics/alpha.md|alpha]] — alpha thing\n"},
        {"type": "custom", "customType": "memory-shadow", "data": {"turn": 0, "kind": "start", "prompt": "do the thing", "query": "q", "ids": {"a": ["m1", "m2"], "b": ["m3"]}}},
        {"type": "message", "message": {"role": "user", "content": "do the thing"}},
        {"type": "message", "message": {"role": "assistant", "content": [
            {"type": "toolCall", "name": "read", "arguments": {"path": str(note)}}]}},
        {"type": "message", "message": {"role": "user", "content": "next"}},
        {"type": "message", "message": {"role": "assistant", "content": [
            {"type": "toolCall", "name": "read", "arguments": {"path": str(wiki / "topics" / "beta.md")}}]}},
    ]
    f.write_text("\n".join(json.dumps(r) for r in rows))
    # a session without shadow entries is ignored
    (d / "s2.jsonl").write_text(json.dumps({"type": "message", "message": {"role": "user", "content": "x"}}))
    return f


def write_log(path, big=False):
    def mem(i, t, n):
        return {"id": i, "text": t, "tokens": n}

    entry = {"ts": "t", "request": {}, "arms": {
        "a": {"memories": [mem("m1", "alpha fact", 100), mem("m2", "junk", 3000 if big else 100)]},
        "b": {"memories": [mem("m3", "unrelated", 50)]}}}
    path.write_text(json.dumps(entry) + "\n")


async def test_relevance_vs_baseline_and_hand_labels(tmp_path):
    sessions, wiki = tmp_path / "sessions", tmp_path / "wiki"
    f = write_session(sessions, wiki)
    log = tmp_path / "recall-log.jsonl"
    write_log(log)
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=[])
    a, b, base = res["a"], res["b"], res["baseline"]
    assert a["labels"] == 2 and a["label_coverage"] == 0.5  # alpha covered, beta not
    assert a["irrelevant_token_share"] == pytest.approx(0.5)
    assert a["mean_injected_tokens"] == 200
    assert b["label_coverage"] == 0.0
    assert base["label_coverage"] == 0.5  # INDEX line mentions alpha
    assert not a["beats_baseline"]  # 0.5 is not > 0.5
    # hand labels no longer change the primary score; merged view drops beta -> only alpha labelled
    hl = [{"session_file": str(f), "turn": 0, "irrelevant_notes": ["topics/beta.md"], "extra_relevant_notes": []}]
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=hl)
    assert res["a"]["labels"] == 2 and res["a"]["label_coverage"] == 0.5
    assert res["a"]["labels_merged"] == 1 and res["a"]["coverage_merged"] == 1.0
    # an extra hand-labelled note adds a label
    (wiki / "topics" / "gamma.md").write_text("gamma")
    hl = [{"session_file": str(f), "turn": 0, "extra_relevant_notes": ["topics/gamma.md"]}]
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=hl)
    assert res["a"]["labels"] == 2 and res["a"]["labels_merged"] == 3


async def test_relevance_budget_violation(tmp_path):
    sessions, wiki = tmp_path / "sessions", tmp_path / "wiki"
    write_session(sessions, wiki)
    log = tmp_path / "recall-log.jsonl"
    write_log(log, big=True)
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=[])
    assert res["a"]["budget_ok"] is False and res["a"]["beats_baseline"] is False


def test_cap_baseline_start_and_topup(monkeypatch):
    kb = [{"msg": m, "turn": 0, "text": f"l{m}{i}", "tokens": t}
          for m, i, t in [(0, 0, 1500), (0, 1, 400), (0, 2, 300), (0, 3, 50), (1, 0, 600), (1, 1, 300), (1, 2, 200), (2, 0, 900)]]
    kept = [k["text"] for k in score._cap_baseline(kb)]
    assert kept == ["l00", "l01", "l10", "l11", "l20"]  # 2000 start (1500+400), 1000 top-up (600+300)


async def test_relevance_baseline_capped_and_uncapped_informational(tmp_path):
    sessions, wiki = tmp_path / "sessions", tmp_path / "wiki"
    f = write_session(sessions, wiki)
    rows = f.read_text().splitlines()
    pad = "\n".join(f"- [[topics/x{i}.md|x{i}]] " + "word " * 600 for i in range(5))
    kb = {"type": "custom_message", "customType": "knowledge-base",
          "content": pad + "\n- [[topics/alpha.md|alpha]] — alpha thing\n"}
    f.write_text("\n".join([json.dumps(kb)] + rows[1:]))
    log = tmp_path / "recall-log.jsonl"
    write_log(log)
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=[])
    assert res["baseline"]["mean_injected_tokens"] <= score.START_BUDGET
    assert res["baseline"]["coverage_auto"] == 0.0  # alpha line fell past the budget
    assert res["baseline_uncapped"]["coverage_auto"] == 0.5 and res["baseline_uncapped"]["informational"]


async def test_hand_labels_cross_check_and_basis(tmp_path):
    sessions, wiki = tmp_path / "sessions", tmp_path / "wiki"
    f = write_session(sessions, wiki)
    log = tmp_path / "recall-log.jsonl"
    write_log(log)
    (wiki / "topics" / "gamma.md").write_text("gamma")
    hl = [{"session_file": str(f), "turn": 0, "irrelevant_notes": ["topics/beta.md"],
           "extra_relevant_notes": ["topics/gamma.md"]}]
    res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=hl)
    a = res["a"]
    assert a["coverage_auto"] == 0.5 and a["labels_auto"] == 2
    assert a["labels_merged"] == 2 and a["coverage_merged"] == 0.5  # alpha + gamma; gamma uncovered
    assert a["label_agreement"] == 0.5 and a["hand_added_notes"] == 1 and a["hand_sessions"] == 1
    assert a["coverage_basis"] == "auto" and a["label_coverage"] == a["coverage_auto"]
    monkeypatch_min = score.MIN_HAND_SESSIONS
    score.MIN_HAND_SESSIONS = 1
    try:
        res = await score.relevance(FakeJudge(), sessions, wiki, log, hand_labels=hl)
    finally:
        score.MIN_HAND_SESSIONS = monkeypatch_min
    assert res["a"]["coverage_basis"] == "merged" and res["a"]["labels"] == 2
    out = score.render({"rule": score.apply_rule(st(a=True), res, {"arms": {}}), "stale_gate": st(a=True),
                        "relevance": res, "cost": {"arms": {}, "judge": {}}})
    assert "merged labels" in out and "label agreement" in out and "uncapped, informational" in out


def st(**kw):
    return {a: {"pass": p, "leaks": 0, "leak_ids": [], "current_present_rate": 1.0, "errors": 0, "pairs": 1}
            for a, p in kw.items()}


def rl(**kw):
    out = {"baseline": {"label_coverage": 0.3, "labels": 1, "irrelevant_token_share": 0.1,
                        "mean_injected_tokens": 10, "sessions": 1}}
    for a, c in kw.items():
        out[a] = {"label_coverage": c, "labels": 1, "irrelevant_token_share": 0.1, "mean_injected_tokens": 10,
                  "sessions": 1, "budget_ok": True, "beats_baseline": c is not None and c > 0.3}
    return out


def test_rule_gate_excludes_better_arm():
    r = score.apply_rule(st(hindsight=False, wiki=True, graphiti=True), rl(hindsight=0.9, wiki=0.5, graphiti=0.6), {"arms": {}})
    assert r["winner"] == "graphiti"


def test_rule_ease_tiebreak_and_cost():
    all_ok, tied = st(wiki=True, graphiti=True, hindsight=True), rl(wiki=0.5, graphiti=0.5, hindsight=0.5)
    assert score.apply_rule(all_ok, tied, {"arms": {}})["ranking"] == ["hindsight", "wiki", "graphiti"]
    costs = {"arms": {"wiki": {"llm_tokens": 5}, "graphiti": {"llm_tokens": 1}, "hindsight": {"llm_tokens": 9}}}
    r = score.apply_rule(all_ok, tied, costs)
    assert r["winner"] == "graphiti" and r["cost_used"]
    r = score.apply_rule(st(wiki=True, graphiti=True), rl(wiki=0.5, graphiti=0.6), costs)
    assert r["winner"] == "graphiti"  # relevance outranks cost and ease
    r = score.apply_rule(st(wiki=True, graphiti=True), rl(wiki=0.6, graphiti=0.5), costs)
    assert r["winner"] == "wiki"


def test_rule_no_winner():
    r = score.apply_rule(st(wiki=True, graphiti=False), rl(wiki=0.2, graphiti=0.9), {"arms": {}})
    assert r["winner"] is None
    out = score.render({"rule": r, "stale_gate": st(wiki=True), "relevance": rl(wiki=0.2),
                        "cost": {"arms": {}, "judge": {}}})
    assert out.startswith("NO-WINNER")


def test_cost_reads_queue_and_usage(tmp_path):
    db = sqlite3.connect(tmp_path / "queue.sqlite")
    db.executescript("CREATE TABLE deliveries (item_id INTEGER, arm TEXT, status TEXT);"
                     "INSERT INTO deliveries VALUES (1,'a','done'),(2,'a','pending'),(1,'b','done');")
    db.commit()
    (tmp_path / "llm-usage.jsonl").write_text(json.dumps({"arm": "a", "input_tokens": 5, "output_tokens": 2}) + "\n")
    c = score.cost(tmp_path)
    assert c["arms"]["a"]["deliveries"] == {"done": 1, "pending": 1} and c["arms"]["a"]["llm_tokens"] == 7
    assert c["arms"]["b"]["llm_tokens"] is None


@respx.mock
async def test_report_end_to_end(tmp_path, eval_env):
    sessions, wiki = tmp_path / "sessions", tmp_path / "wiki"
    write_session(sessions, wiki)
    state = tmp_path / "state"
    state.mkdir()
    write_log(state / "recall-log.jsonl")
    (score.eval_dir() / "supersession_pairs.jsonl").write_text("\n".join(json.dumps(p) for p in PAIRS))
    mock_gateway({"a": {"q0": ["CURRENT"]}, "b": {"q0": ["CURRENT"]}})
    mock_lineage({"a": {}, "b": {}}, {})
    cfg = Config(state_dir=str(state))
    res = await score.report(cfg, GW, score.CachedJudge(FakeJudge()), sessions, wiki)
    md = (eval_env / "report.md").read_text()
    assert md.startswith("NO-WINNER")  # neither arm beats the baseline
    assert json.loads((eval_env / "report.json").read_text())["rule"]["winner"] is None
    assert res["stale_gate"]["a"]["pass"]


async def test_bedrock_judge_sends_no_sampling_params():
    from types import SimpleNamespace

    from memory_gateway.config import Config

    seen = {}

    class C:
        def __init__(self):
            self.messages = self

        async def create(self, *, max_tokens, messages, model, system, tools, tool_choice,
                         **kw):
            assert "temperature" not in kw
            assert "temperature" not in (kw.get("extra_body") or {})
            seen.update(kw)
            return SimpleNamespace(content=[SimpleNamespace(type="tool_use", input={})], usage=None)

    j = score.BedrockJudge(Config(), client=C())
    await j(next(iter(score._SCHEMAS)), {})
    assert "extra_body" not in seen


LPAIRS = [{"id": f"p{i:02d}", "project": None, "question": f"q{i}", "stale_fact": "s", "current_fact": "c"} for i in range(25)]


def mock_lineage(hist, sources):
    """hist: arm -> {query: texts}; sources: arm -> source dict or {'error': ..} (None -> null)."""
    def history(request):
        body = json.loads(request.content)
        arm = body["arms"][0]
        texts = hist[arm].get(body["query"], [])
        return httpx.Response(200, json={"results": {arm: [{"id": "m", "text": t, "tokens": 5} for t in texts]}, "errors": {}})

    def source(request):
        body = json.loads(request.content)
        s = sources.get(body["arm"])
        if isinstance(s, dict) and "error" in s:
            return httpx.Response(200, json={"arm": body["arm"], "source": None, "error": s["error"]})
        return httpx.Response(200, json={"arm": body["arm"], "source": s, "error": None})

    respx.post(f"{GW}/history").mock(side_effect=history)
    respx.post(f"{GW}/source").mock(side_effect=source)


def lin_setup(recall_ok=10):
    qs = [p["question"] for p in score._sample_pairs(LPAIRS)]
    assert len(qs) == 10 and len(set(qs)) == 10
    return qs


@respx.mock
async def test_lineage_pass_and_sampling():
    qs = lin_setup()
    mock_gateway({"a": {q: ["CURRENT"] for q in qs}}, arms=("a",))
    mock_lineage({"a": {q: ["STALE"] for q in qs}}, {"a": {"memory_id": "m", "source_ref": "r", "text": "BACKED", "ts": "t"}})
    res = await score.lineage(GW, FakeJudge(), LPAIRS)
    assert res["a"]["traced"] == 10 and res["a"]["replaced_found"] == 10 and res["a"]["pass"]
    assert res["a"]["pair_ids"][0] == "p00" and res["a"]["pair_ids"][-1] >= "p20"  # spans the file


@respx.mock
async def test_lineage_fails_on_trace():
    qs = lin_setup()
    mock_gateway({"a": {q: ["CURRENT"] for q in qs[:8]}}, arms=("a",))  # 2 recalls miss -> traced 8
    mock_lineage({"a": {q: ["STALE"] for q in qs}}, {"a": {"memory_id": "m", "source_ref": "r", "text": "BACKED", "ts": "t"}})
    res = await score.lineage(GW, FakeJudge(), LPAIRS)
    assert res["a"]["traced"] == 8 and not res["a"]["pass"]


@respx.mock
async def test_lineage_fails_on_unsupported_and_missing_source():
    qs = lin_setup()
    mock_gateway({"a": {q: ["CURRENT"] for q in qs}, "b": {q: ["CURRENT"] for q in qs}}, arms=("a", "b"))
    mock_lineage({"a": {q: ["STALE"] for q in qs}, "b": {q: ["STALE"] for q in qs}},
                 {"a": {"memory_id": "m", "source_ref": "r", "text": "unrelated", "ts": "t"}, "b": {"error": "gone"}})
    res = await score.lineage(GW, FakeJudge(), LPAIRS)
    assert res["a"]["traced"] == 0 and not res["a"]["pass"]
    assert res["b"]["traced"] == 0 and not res["b"]["pass"]


@respx.mock
async def test_lineage_fails_on_history_without_stale():
    qs = lin_setup()
    mock_gateway({"a": {q: ["CURRENT"] for q in qs}}, arms=("a",))
    mock_lineage({"a": {q: ["STALE"] for q in qs[:7]}}, {"a": {"memory_id": "m", "source_ref": "r", "text": "BACKED", "ts": "t"}})
    res = await score.lineage(GW, FakeJudge(), LPAIRS)
    assert res["a"]["traced"] == 10 and res["a"]["replaced_found"] == 7 and not res["a"]["pass"]


def test_rule_requires_lineage_gate():
    lin = {"hindsight": {"pass": False, "traced": 0, "replaced_found": 0, "pairs": 10, "errors": 0},
           "wiki": {"pass": True, "traced": 10, "replaced_found": 10, "pairs": 10, "errors": 0}}
    r = score.apply_rule(st(hindsight=True, wiki=True), rl(hindsight=0.9, wiki=0.5), {"arms": {}}, lin)
    assert r["winner"] == "wiki" and r["passed_stale_gate"] == ["wiki"]
    out = score.render({"rule": r, "stale_gate": st(wiki=True), "lineage": lin, "relevance": rl(wiki=0.5),
                        "cost": {"arms": {}, "judge": {}}})
    assert "## Lineage gate" in out
