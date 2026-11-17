import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const home = mkdtempSync(join(tmpdir(), "token-ledger-test-"));
process.env.HOME = home;
const LEDGER = join(home, ".local", "share", "pi", "token-ledger.jsonl");

const { default: ext } = await import("./token-ledger.ts");

type Handler = (event: any) => any;
function setup() {
  const handlers = new Map<string, Handler>();
  const commands = new Map<string, any>();
  ext({
    on: (name: string, h: Handler) => void handlers.set(name, h),
    registerCommand: (name: string, def: any) => void commands.set(name, def),
  } as any);
  const messages: string[] = [];
  const ctx = { ui: { notify: (m: string) => void messages.push(m) } };
  return {
    fire: (name: string, ev: any = {}) => handlers.get(name)!(ev),
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

describe("token-ledger", () => {
  beforeEach(() => rmSync(LEDGER, { force: true }));

  it("sums assistant usage and writes on agent_settled, then resets", async () => {
    const t = setup();
    await t.fire("session_start");
    t.fire("message_end", asst(usage(10, 5, 100, 20, 0.25)));
    t.fire("message_end", { message: { role: "user", usage: usage(999, 999, 999, 999, 9) } });
    t.fire("message_end", asst(usage(1, 2, 3, 4, 0.5)));
    assert.equal(entries().length, 0);
    await t.fire("agent_settled");
    await t.fire("agent_settled");
    const [a, b] = entries();
    assert.equal(a.event, "turn");
    assert.equal(a.taskId, null);
    assert.deepEqual(a.tokens, { input: 11, output: 7, cacheRead: 103, cacheWrite: 24 });
    assert.equal(a.cost, 0.75);
    assert.deepEqual(b.tokens, { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 });
    assert.equal(b.cost, 0);
  });

  it("message_end handler returns nothing, even with partial usage", () => {
    const t = setup();
    assert.equal(t.fire("message_end", asst({ input: 1 })), undefined);
  });

  it("logs warm decisions only, returns undefined", async () => {
    const t = setup();
    await t.fire("session_start");
    assert.equal(t.fire("cache_warming_decision", { action: "warm", warmCost: 0.04, missCost: 1, continuationProbability: 0.9 }), undefined);
    assert.equal(t.fire("cache_warming_decision", { action: "stop", warmCost: 0.04, missCost: 1, continuationProbability: 0.1 }), undefined);
    const e = entries();
    assert.equal(e.length, 1);
    assert.equal(e[0].event, "warm");
    assert.equal(e[0].cost, 0.04);
    assert.equal(e[0].taskId, null);
  });

  it("ignores non-literal claim/close ids; literal claim sets the task", async () => {
    const t = setup();
    await t.fire("session_start");
    await t.bash("bd update $T --claim");
    await t.bash("bd update $(bd ready) --claim");
    assert.equal(entries().length, 0);
    await t.bash("bd update dotfiles-1.2 --claim");
    await t.fire("agent_settled");
    await t.bash("bd close $id");
    await t.fire("agent_settled");
    const e = entries();
    assert.deepEqual(e.map((x) => x.event), ["claim", "turn", "turn"]);
    assert.equal(e[1].taskId, "dotfiles-1.2");
    assert.equal(e[2].taskId, "dotfiles-1.2");
    await t.bash("bd close dotfiles-1.2");
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
    t.fire("cache_warming_decision", { action: "warm", warmCost: 0.1 });
    await t.bash("bd update ep-1.1 --claim");
    t.fire("message_end", asst(usage(1, 1, 0, 0, 2.6)));
    await t.fire("agent_settled");
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
});
