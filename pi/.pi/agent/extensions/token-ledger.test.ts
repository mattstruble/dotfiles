import { describe, it, beforeEach, after } from "node:test";
import * as assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const home = mkdtempSync(join(tmpdir(), "token-ledger-test-"));
process.env.HOME = home;
const LEDGER = join(home, ".local", "share", "pi", "token-ledger.jsonl");

const { default: ext } = await import("./token-ledger.ts");

type Handler = (event: any, ctx?: any) => any;
function setup() {
  const sessionEntries: any[] = [];
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, any>();
  ext({
    on: (name: string, h: Handler) => void handlers.set(name, h),
    registerCommand: (name: string, def: any) => void commands.set(name, def),
  } as any);
  const messages: string[] = [];
  const ctx = {
    ui: { notify: (m: string) => void messages.push(m) },
    sessionManager: { getEntries: () => sessionEntries },
  };
  return {
    sessionEntries,
    fire: (name: string, ev: any = {}) => handlers.get(name)!(ev, ctx),
    run: async (name: string, args = "") => {
      messages.length = 0;
      await commands.get(name).handler(args, ctx);
      return messages.join("\n");
    },
    bash: (command: string) => handlers.get("tool_call")!({ toolName: "bash", input: { command } }),
  };
}
const entries = (): any[] =>
  existsSync(LEDGER)
    ? readFileSync(LEDGER, "utf-8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l))
    : [];
const usage = (input: number, output: number, cacheRead: number, cacheWrite: number, total: number) => ({
  input, output, cacheRead, cacheWrite, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total },
});
const asst = (u: any) => ({ message: { role: "assistant", usage: u } });
const warmEntry = (id: string, total: number) => ({
  type: "usage", id, kind: "cache_warm", provider: "p", model: "m", usage: usage(0, 0, 0, 0, total),
});

describe("token-ledger", () => {
  beforeEach(() => rmSync(LEDGER, { force: true }));
  after(() => rmSync(home, { recursive: true, force: true }));

  it("sums assistant usage and writes on agent_settled, then resets", async () => {
    const t = setup();
    await t.fire("session_start");
    t.fire("message_end", asst(usage(10, 5, 100, 20, 0.25)));
    t.fire("message_end", { message: { role: "user", usage: usage(999, 999, 999, 999, 9) } });
    t.fire("message_end", asst(usage(1, 2, 3, 4, 0.5)));
    assert.equal(entries().length, 0);
    await t.fire("agent_settled");
    await t.fire("agent_settled");
    assert.equal(entries().length, 1);
    const [a] = entries();
    assert.equal(a.event, "turn");
    assert.equal(a.taskId, null);
    assert.deepEqual(a.tokens, { input: 11, output: 7, cacheRead: 103, cacheWrite: 24 });
    assert.equal(a.cost, 0.75);
  });

  it("zero-usage settle writes no turn", async () => {
    const t = setup();
    await t.fire("session_start");
    await t.fire("agent_settled");
    assert.equal(entries().length, 0);
  });

  it("claim + usage + close in one run attributes the turn to that task", async () => {
    const t = setup();
    await t.fire("session_start");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 0.1)));
    await t.bash("bd update x-9 --claim");
    t.fire("message_end", asst(usage(2, 3, 4, 5, 0.7)));
    await t.bash("bd close x-9");
    await t.fire("agent_settled");
    const e = entries();
    assert.deepEqual(e.map((x) => [x.event, x.taskId]), [
      ["turn", null], ["claim", "x-9"], ["turn", "x-9"], ["close", "x-9"],
    ]);
    assert.equal(e[0].cost, 0.1);
    assert.equal(e[2].cost, 0.7);
    assert.deepEqual(e[2].tokens, { input: 2, output: 3, cacheRead: 4, cacheWrite: 5 });
  });

  it("message_end handler returns nothing, even with partial usage", () => {
    const t = setup();
    assert.equal(t.fire("message_end", asst({ input: 1 })), undefined);
  });

  it("logs completed cache_warm usage entries once; skips pre-existing ones", async () => {
    const t = setup();
    t.sessionEntries.push(warmEntry("old", 9), { type: "message", id: "m1" });
    await t.fire("session_start");
    assert.equal(t.fire("cache_warming_decision", { action: "warm", warmCost: 0.04 }), undefined);
    assert.equal(t.fire("cache_warming_decision", { action: "stop" }), undefined);
    assert.equal(entries().length, 0);
    t.sessionEntries.push(warmEntry("new", 0.03));
    await t.fire("agent_settled");
    await t.fire("session_shutdown");
    await t.fire("agent_start");
    const e = entries();
    assert.equal(e.length, 1);
    assert.deepEqual(Object.keys(e[0]), ["ts", "taskId", "sessionId", "event", "cost", "model"]);
    assert.equal(e[0].event, "warm");
    assert.equal(e[0].cost, 0.03);
    assert.equal(e[0].model, "m");
    assert.equal(e[0].taskId, null);
  });

  it("tolerates a missing sessionManager", async () => {
    const handlers = new Map<string, Handler>();
    ext({ on: (n: string, h: Handler) => void handlers.set(n, h), registerCommand: () => {} } as any);
    await handlers.get("session_start")!({}, {});
    assert.equal(handlers.get("cache_warming_decision")!({ action: "warm" }, {}), undefined);
    await handlers.get("agent_settled")!({}, undefined);
    assert.equal(entries().length, 0);
  });

  it("ignores non-literal claim/close ids; literal claim sets the task", async () => {
    const t = setup();
    await t.fire("session_start");
    await t.bash("bd update $T --claim");
    await t.bash("bd update $(bd ready) --claim");
    assert.equal(entries().length, 0);
    await t.bash("bd update dotfiles-1.2 --claim");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 0.2)));
    await t.fire("agent_settled");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 0.3)));
    await t.bash("bd close $id");
    await t.fire("agent_settled");
    const e = entries();
    assert.deepEqual(e.map((x) => x.event), ["claim", "turn", "turn"]);
    assert.equal(e[1].taskId, "dotfiles-1.2");
    assert.equal(e[2].taskId, "dotfiles-1.2");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 0.4)));
    await t.bash("bd close dotfiles-1.2");
    assert.equal(entries().at(-2).event, "turn");
    assert.equal(entries().at(-2).taskId, "dotfiles-1.2");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 0.5)));
    await t.fire("agent_settled");
    assert.equal(entries().at(-1).taskId, null);
  });

  it("does not log dispatch without a task", async () => {
    const t = setup();
    await t.fire("session_start");
    await t.fire("tool_call", { toolName: "subagent", input: {} });
    assert.equal(entries().length, 0);
    await t.bash("bd update x-1 --claim");
    await t.fire("tool_call", { toolName: "subagent", input: { tasks: [1, 2] } });
    assert.equal(entries().at(-1).event, "dispatch");
    assert.equal(entries().at(-1).children, 2);
  });

  it("/cost handles null-task entries and prints dollars", async () => {
    const t = setup();
    await t.fire("session_start");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 1.5)));
    await t.fire("agent_settled");
    t.sessionEntries.push(warmEntry("w1", 0.1));
    t.fire("cache_warming_decision", { action: "warm", warmCost: 0.1 });
    await t.bash("bd update ep-1.1 --claim");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 2.6)));
    await t.fire("agent_settled");
    t.sessionEntries.push(warmEntry("w2", 0.28));
    t.fire("cache_warming_decision", { action: "warm", warmCost: 0.28 });
    await t.fire("tool_call", { toolName: "subagent", input: {} });

    assert.equal(await t.run("cost", "--epic ep-1"), "Epic ep-1: 1 turns $2.60 · warming 1× $0.28 · 1 dispatches");
    assert.equal(await t.run("cost", "ep-1.1"), "Task ep-1.1: 1 turns $2.60 · warming 1× $0.28 · 1 dispatches");
    assert.equal(await t.run("cost", "ep-1"), "No ledger entries for task ep-1");
    assert.equal(await t.run("cost"), "Session: 2 turns $4.10 · warming 2× $0.38 · 1 dispatches");
    const l = await t.run("ledger", "10");
    assert.match(l, /\[warm    \] -/);
    assert.match(l, /\$1\.500/);
  });

  it("tolerates old-format lines without cost", async () => {
    const t = setup();
    await t.fire("session_start");
    writeFileSync(
      LEDGER,
      [
        { ts: "2025-01-01T00:00:00Z", taskId: "old-1", sessionId: "s", event: "claim" },
        { ts: "2025-01-01T00:00:01Z", taskId: "old-1", sessionId: "s", event: "turn", tokens: { input: 3, output: 4 } },
        { ts: "2025-01-01T00:00:02Z", taskId: "old-1", sessionId: "s", event: "dispatch", children: 1 },
      ].map((x) => JSON.stringify(x)).join("\n") + "\n",
    );
    assert.equal(await t.run("cost", "old-1"), "Task old-1: 1 turns $0.00 · warming 0× $0.00 · 1 dispatches");
    assert.match(await t.run("ledger"), /old-1 \(3→4\)/);
  });

  it("skips a malformed ledger line and summarizes the rest", async () => {
    const t = setup();
    await t.fire("session_start");
    const good = (cost: number) =>
      JSON.stringify({ ts: "2025-01-01T00:00:00Z", taskId: "bad-1", sessionId: "s", event: "turn", cost });
    writeFileSync(LEDGER, [good(1), "{not json", good(2)].join("\n") + "\n");
    assert.equal(await t.run("cost", "bad-1"), "Task bad-1: 2 turns $3.00 · warming 0× $0.00 · 0 dispatches");
  });
});
