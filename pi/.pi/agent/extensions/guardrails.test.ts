import { it } from "node:test";
import * as assert from "node:assert/strict";
import {
  bdInitBlockReason,
  bdVerbs,
  createMcpGate,
  MCP_DECISION_EVENT,
  MCP_PROMPT_EVENT,
  needsApproval,
  nestedCallReason,
  parseMcpTool,
  READ_ALLOWLIST_FLAT,
} from "./guardrails.ts";

it("requires approval unless readOnlyHint is true or allowlisted", () => {
  const tool = "mcp__srv__do_thing";
  assert.equal(needsApproval(tool, undefined, []), true);
  assert.equal(needsApproval(tool, {}, []), true);
  assert.equal(needsApproval(tool, { readOnlyHint: true }, []), false);
  assert.equal(needsApproval(tool, { readOnlyHint: true, destructiveHint: true }, []), false);
  assert.equal(needsApproval(tool, { readOnlyHint: false }, []), true);
  assert.equal(needsApproval(tool, undefined, [tool]), false);
});

it("passes allowlisted tools from servers without annotations", () => {
  assert.equal(needsApproval("mcp__nixos__nix", undefined, READ_ALLOWLIST_FLAT), false);
});

it("blocks workflow and subagent only when another tool issued the call", () => {
  assert.match(nestedCallReason("workflow", "call_1") ?? "", /directly/);
  assert.match(nestedCallReason("subagent", "call_1") ?? "", /directly/);
  assert.equal(nestedCallReason("workflow", undefined), undefined);
  assert.equal(nestedCallReason("bash", "call_1"), undefined);
});

it("extracts bd verbs per segment", () => {
  assert.deepEqual(bdVerbs("cd x && bd init -p y"), ["init"]);
  assert.deepEqual(bdVerbs("bd -v --db x list; bd show a | cat"), ["list", "show"]);
  assert.deepEqual(bdVerbs("echo bd init"), []);
});

it("blocks bd init and bd setup", () => {
  for (const c of [
    "bd init",
    "bd init --stealth",
    "cd x && bd init -p y",
    "BEADS_DIR=/x bd init",
    "env -u BEADS_DIR bd init",
    "command bd init",
    "/nix/store/abc/bin/bd init",
    "bd -v init",
    "bd setup claude",
  ]) {
    assert.match(bdInitBlockReason(c) ?? "", /never run bd init or bd setup/, c);
  }
});

it("allows other bd commands", () => {
  for (const c of ["bd list", 'bd q "fix the init docs"', "bd show x", "echo bd init"]) {
    assert.equal(bdInitBlockReason(c), undefined, c);
  }
});

it("parses mcp__<server>__<tool>", () => {
  assert.deepEqual(parseMcpTool("mcp__notion__notion_update_page"), { server: "notion", tool: "notion_update_page" });
  assert.deepEqual(parseMcpTool("mcp__pdf_fast__read"), { server: "pdf_fast", tool: "read" });
  assert.equal(parseMcpTool("mcp__x"), null);
  assert.equal(parseMcpTool("mcp__a__b__c"), null);
});

function harness(answer: (options: string[]) => string | undefined | Promise<string | undefined>) {
  const events: string[] = [];
  const prompts: string[][] = [];
  const gate = createMcpGate((channel) => events.push(channel));
  const select = async (_title: string, options: string[]) => {
    prompts.push(options);
    return answer(options);
  };
  const ask = (tool: string) => gate.request(tool, "{}", select);
  return { gate, ask, events, prompts };
}

const UPDATE = "mcp__notion__notion_update_page";
const CREATE = "mcp__notion__notion_create_page";

it("once and no do not grant", async () => {
  const h = harness((o) => (h.prompts.length === 1 ? o[0] : "No"));
  assert.equal(await h.ask(UPDATE), true);
  assert.equal(await h.ask(UPDATE), false);
  assert.equal(await h.ask(UPDATE), false);
  assert.equal(h.prompts.length, 3);
  assert.equal(await harness(() => undefined).ask(UPDATE), false);
});

it("tool grant covers only that tool", async () => {
  const h = harness((o) => o.find((x) => x.includes(UPDATE)));
  assert.equal(await h.ask(UPDATE), true);
  assert.equal(await h.ask(UPDATE), true);
  assert.equal(h.prompts.length, 1);
  await h.ask(CREATE);
  assert.equal(h.prompts.length, 2);
});

it("server grant settles prompts already queued", async () => {
  const h = harness((o) => o.find((x) => x.includes("all notion")));
  assert.deepEqual(await Promise.all([h.ask(UPDATE), h.ask(CREATE), h.ask(UPDATE)]), [true, true, true]);
  assert.equal(h.prompts.length, 1);
  assert.deepEqual(h.events, [MCP_PROMPT_EVENT, MCP_DECISION_EVENT]);
});

it("offers no server option when the name has no server", async () => {
  const h = harness(() => "No");
  await h.ask("mcp__x");
  assert.equal(h.prompts[0].length, 3);
});

it("a throwing select is a denial and the queue continues", async () => {
  const h = harness((o) => {
    if (h.prompts.length === 1) throw new Error("dialog failed");
    return o[0];
  });
  assert.deepEqual(await Promise.all([h.ask(UPDATE), h.ask(UPDATE)]), [false, true]);
  assert.deepEqual(h.events, [MCP_PROMPT_EVENT, MCP_DECISION_EVENT, MCP_PROMPT_EVENT, MCP_DECISION_EVENT]);
});

it("reset clears grants and ignores answers from the old session", async () => {
  const h = harness((o) => o.find((x) => x.includes("all notion")));
  await h.ask(UPDATE);
  h.gate.reset();
  await h.ask(UPDATE);
  assert.equal(h.prompts.length, 2);

  let release: () => void = () => {};
  const s = harness((o) => {
    const grant = o.find((x) => x.includes("all notion"));
    if (s.prompts.length > 1) return "No";
    return new Promise((r) => (release = () => r(grant)));
  });
  const pending = s.ask(UPDATE);
  await new Promise((r) => setImmediate(r));
  s.gate.reset();
  release();
  assert.equal(await pending, false);
  assert.equal(await s.ask(UPDATE), false);
  assert.equal(s.prompts.length, 2);
});

it("denies any answer that is not an approve label", async () => {
  for (const answer of ["garbage", "", "no", "yes, once"]) {
    assert.equal(await harness(() => answer).ask(UPDATE), false, answer);
  }
});

it("an aborted request is denied and frees the queue", async () => {
  const prompts: string[] = [];
  const gate = createMcpGate(() => {});
  const hung = (title: string, _o: string[], signal?: AbortSignal) => {
    prompts.push(title);
    return new Promise<string | undefined>((r) => signal?.addEventListener("abort", () => r(undefined)));
  };
  const a = new AbortController();
  const first = gate.request(UPDATE, "{}", hung, a.signal);
  const queued = gate.request(CREATE, "{}", hung, a.signal);
  await new Promise((r) => setImmediate(r));
  a.abort();
  assert.deepEqual(await Promise.all([first, queued]), [false, false]);
  assert.equal(prompts.length, 1);
  assert.equal(await gate.request(UPDATE, "{}", async (_t, o) => o[0]), true);
});

it("a throwing listener does not break the prompt or the decision event", async () => {
  const seen: string[] = [];
  const gate = createMcpGate((channel) => {
    seen.push(channel);
    throw new Error("listener failed");
  });
  assert.equal(await gate.request(UPDATE, "{}", async (_t, o) => o[0]), true);
  assert.deepEqual(seen, [MCP_PROMPT_EVENT, MCP_DECISION_EVENT]);
});
