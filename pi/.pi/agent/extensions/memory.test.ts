/**
 * Run: npx tsx --test pi/.pi/agent/extensions/memory.test.ts
 */
import { describe, it } from "node:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir, homedir } from "node:os";
import { join } from "node:path";
import * as assert from "node:assert/strict";
import {
  createMemoryExtension, loadClientConfig, projectFromCommonDir, makeProjectResolver, redact,
  stripInjected, serializeEntries, recoverCursor, entriesAfterCursor, recoverRecallState,
  isTopicShift, jaccard, wordSet, filterNew, formatMemoryBlock, idsPerArm, isDerivedReadPath, chunkText,
} from "./memory.ts";

const msg = (id: string, role: string, content: any, extra: any = {}) => ({
  type: "message", id, parentId: null, timestamp: "2025-01-01T00:00:00Z", message: { role, content, ...extra },
});

function cfgFile(obj: unknown): string {
  const p = join(mkdtempSync(join(tmpdir(), "mem-")), "client.json");
  writeFileSync(p, typeof obj === "string" ? obj : JSON.stringify(obj));
  return p;
}

function fakePi() {
  const handlers: Record<string, Function> = {};
  const tools: Record<string, any> = {};
  const entries: any[] = [];
  return {
    handlers, tools, entries,
    on: (n: string, h: Function) => { handlers[n] = h; },
    registerTool: (t: any) => { tools[t.name] = t; },
    appendEntry: (type: string, data: any) => entries.push({ type: "custom", customType: type, data }),
  };
}

function mockFetch(responder: (path: string, body: any) => any) {
  const calls: Array<{ path: string; body: any }> = [];
  const fn = async (url: string, init: any) => {
    const path = new URL(url).pathname;
    const body = JSON.parse(init.body);
    calls.push({ path, body });
    const r = responder(path, body);
    if (r === "fail") throw new Error("boom");
    if (typeof r === "number") return { ok: false, status: r, json: async () => ({}) };
    return { ok: true, status: path === "/ingest" ? 202 : 200, json: async () => r };
  };
  return { fn: fn as any, calls };
}

const ctxFor = (branch: any[]) => ({
  cwd: "/r/proj",
  sessionManager: { getBranch: () => branch, getEntries: () => branch, getSessionId: () => "s1" },
});
const git = () => "/r/proj/.git";

describe("config", () => {
  it("missing/unparsable => off", () => {
    assert.equal(loadClientConfig("/nonexistent/x.json").mode, "off");
    assert.equal(loadClientConfig(cfgFile("{nope")).mode, "off");
  });
  it("parses modes and defaults", () => {
    const c = loadClientConfig(cfgFile({ mode: "shadow" }));
    assert.equal(c.mode, "shadow");
    assert.equal(c.startBudget, 2000);
    assert.equal(loadClientConfig(cfgFile({ mode: "weird" })).mode, "off");
  });
  it("mode off registers nothing and makes no calls", () => {
    const pi = fakePi();
    const m = mockFetch(() => ({}));
    createMemoryExtension({ configPath: cfgFile({ mode: "off" }), fetchImpl: m.fn })(pi as any);
    assert.deepEqual(Object.keys(pi.handlers), []);
    assert.deepEqual(Object.keys(pi.tools), []);
    assert.equal(m.calls.length, 0);
  });
});

describe("project tag", () => {
  it("maps main and linked worktree to repo name", () => {
    assert.equal(projectFromCommonDir("/Users/x/Dotfiles/.git"), "dotfiles");
    const r = makeProjectResolver(() => "/Users/x/dotfiles/.git");
    assert.equal(r("/Users/x/dotfiles/.pi/worktrees/t1"), "dotfiles");
  });
  it("non-git => null, cached", () => {
    let n = 0;
    const r = makeProjectResolver(() => { n++; return null; });
    assert.equal(r("/tmp/a"), null);
    assert.equal(r("/tmp/a"), null);
    assert.equal(n, 1);
  });
});

describe("redaction", () => {
  const cases: Array<[string, string]> = [
    ["key AKIAIOSFODNN7EXAMPLE here", "AKIAIOSFODNN7EXAMPLE"],
    ["id ASIAIOSFODNN7EXAMPLE", "ASIAIOSFODNN7EXAMPLE"],
    ["aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", "wJalrXUtnFEMI"],
    ["ghp_abcdefghijklmnopqrstuvwxyz0123456789", "ghp_abcdef"],
    ["gho_abcdefghijklmnopqrstuvwxyz0123456789", "gho_abcdef"],
    ["github_pat_11ABCDEFG0abcdefghijklmnop_qrstuv", "github_pat_11"],
    ["xoxb-123456789012-abcdefghij", "xoxb-1234"],
    ["sk-ant-api03-abcdefghijklmnopqrstuvwxyz", "sk-ant-api03"],
    ["sk-abcdefghijklmnopqrstuvwxyz123456", "sk-abcdefgh"],
    ["Authorization: Bearer abc123DEF456ghi789", "abc123DEF456ghi789"],
    ["-----BEGIN RSA PRIVATE KEY-----\nMIIEabc\n-----END RSA PRIVATE KEY-----", "MIIEabc"],
    ["eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abcDEF_123-xyz", "eyJzdWIi"],
    ["password=hunter2hunter2", "hunter2"],
    ["API_KEY: 'abcd1234'", "abcd1234"],
    ["token = zzz999", "zzz999"],
  ];
  for (const [input, secret] of cases) {
    it(`redacts ${input.slice(0, 24)}`, () => {
      const out = redact(input);
      assert.ok(out.includes("[REDACTED]"), out);
      assert.ok(!out.includes(secret), out);
    });
  }
  it("no false positives on prose / SHAs", () => {
    const s = "Commit f2ea83d53228c658ff68cdbbfb32eb8e61af415d fixed the sky-high latency; the task is done.";
    assert.equal(redact(s), s);
  });
});

describe("stripping and serialisation", () => {
  it("strips blocks and private", () => {
    const t = stripInjected("a <private>secret stuff</private> b <available_skills>x</available_skills> c <skill name=\"n\">body</skill> d");
    assert.equal(t.replace(/\s+/g, " "), "a b c d");
  });
  it("drops derived custom_message and own entries", () => {
    const es = [
      ...["skill-router", "knowledge-base", "memory"].map((c, i) => ({ type: "custom_message", customType: c, id: `c${i}`, content: "INJECTED", timestamp: "t" })),
      { type: "custom", customType: "memory-ingest", data: { cursorEntryId: "x" }, id: "i" },
      { type: "custom", customType: "memory-shadow", data: {}, id: "j" },
      msg("m1", "user", [{ type: "text", text: "hello world" }]),
    ];
    const out = serializeEntries(es);
    assert.ok(!out.includes("INJECTED"));
    assert.ok(out.includes("[user 2025-01-01T00:00:00Z]\nhello world"));
  });
  it("assistant: drops thinking, formats tool calls, truncates args", () => {
    const out = serializeEntries([
      msg("a", "assistant", [
        { type: "thinking", thinking: "SECRETTHOUGHT" },
        { type: "text", text: "doing it" },
        { type: "toolCall", id: "t1", name: "bash", arguments: { command: "x".repeat(500) } },
      ]),
    ]);
    assert.ok(!out.includes("SECRETTHOUGHT"));
    assert.ok(out.includes("doing it"));
    const line = out.split("\n").find((l) => l.startsWith("tool bash: "))!;
    assert.ok(line.length <= "tool bash: ".length + 301);
  });
  it("tool results truncated to 1000", () => {
    const out = serializeEntries([msg("r", "toolResult", [{ type: "text", text: "y".repeat(5000) }], { toolName: "bash", toolCallId: "z" })]);
    assert.ok(out.length < 1100);
  });
  it("drops read results of skill/wiki paths, keeps others", () => {
    const home = homedir();
    const call = (id: string, path: string) => msg(`a${id}`, "assistant", [{ type: "toolCall", id, name: "read", arguments: { path } }]);
    const res = (id: string, text: string) => msg(`r${id}`, "toolResult", [{ type: "text", text }], { toolName: "read", toolCallId: id });
    const es = [
      call("1", `${home}/.pi/agent/skill-profiles/all/x/SKILL.md`), res("1", "SKILLBODY"),
      call("2", "/repo/foo/SKILL.md"), res("2", "SKILLBODY2"),
      call("3", `${home}/llm-wiki/topics/a.md`), res("3", "WIKIBODY"),
      call("4", "/repo/src/main.ts"), res("4", "REALCODE"),
    ];
    const out = serializeEntries(es);
    assert.ok(!out.includes("SKILLBODY") && !out.includes("WIKIBODY"));
    assert.ok(out.includes("REALCODE"));
    assert.ok(isDerivedReadPath("~/llm-wiki/x.md"));
  });
  it("strips <memory> blocks from all serialised text", () => {
    assert.equal(stripInjected("a <memory>m1</memory> b <memory>\nm2\n</memory> c <memory>open").replace(/\s+/g, " ").trim(), "a b c");
    const out = serializeEntries([
      msg("u", "user", "hi <memory>RECALLU</memory> there"),
      msg("a", "assistant", [
        { type: "text", text: "ok <memory>RECALLA</memory>" },
        { type: "toolCall", id: "t", name: "subagent", arguments: { task: "do it\n\n<memory>\nRECALLT\n</memory>" } },
        { type: "toolCall", id: "t2", name: "subagent", arguments: { task: "do it\n<memory>RECALLX" } },
      ]),
      msg("r", "toolResult", [{ type: "text", text: "out <memory>RECALLR</memory>" }], { toolName: "bash", toolCallId: "q" }),
    ]);
    assert.ok(!out.includes("RECALL"));
    assert.ok(out.includes("hi") && out.includes("do it") && out.includes("out"));
  });
  it("omits memory_recall results entirely", () => {
    const out = serializeEntries([msg("r", "toolResult", [{ type: "text", text: "RECALLED fact without tags" }], { toolName: "memory_recall", toolCallId: "q" })]);
    assert.ok(!out.includes("RECALLED"));
    assert.ok(out.includes("tool memory_recall: [recalled memories omitted]"));
  });
  it("redacts in serialised output", () => {
    const out = serializeEntries([msg("u", "user", "my password=abc12345 ok")]);
    assert.ok(!out.includes("abc12345"));
  });
});

describe("cursor", () => {
  const es = [msg("a", "user", "1"), msg("b", "user", "2"), msg("c", "user", "3")];
  it("recovers latest cursor", () => {
    const withCur = [...es, { type: "custom", customType: "memory-ingest", data: { cursorEntryId: "b" }, id: "d" }];
    assert.equal(recoverCursor(withCur), "b");
    assert.equal(recoverCursor(es), null);
  });
  it("delta after cursor; unknown cursor => all", () => {
    assert.deepEqual(entriesAfterCursor(es, "b").map((e) => e.id), ["c"]);
    assert.equal(entriesAfterCursor(es, "zzz").length, 3);
    assert.equal(entriesAfterCursor(es, null).length, 3);
  });
});

describe("topic shift and dedup", () => {
  it("jaccard / shift", () => {
    assert.equal(isTopicShift("anything here", null), false);
    assert.equal(isTopicShift("fix the kubernetes deployment rollout", "fix kubernetes deployment rollout please"), false);
    assert.equal(isTopicShift("write poetry about autumn leaves", "fix kubernetes deployment rollout"), true);
    assert.equal(jaccard(new Set(["a"]), new Set(["b"])), 0);
    assert.ok(!wordSet("the and cat this").has("this"));
  });
  it("filterNew dedups injected and duplicates", () => {
    const items = [{ id: "1", text: "a" }, { id: "2", text: "b" }, { id: "2", text: "b" }];
    assert.deepEqual(filterNew(items, new Set(["1"])).map((i) => i.id), ["2"]);
  });
  it("recovers injected ids", () => {
    const st = recoverRecallState([{ type: "custom_message", customType: "memory", details: { ids: ["x", "y"], prompt: "p" } }]);
    assert.ok(st.injectedIds.has("x") && st.injectedIds.has("y"));
    assert.equal(st.lastPrompt, "p");
  });
  it("format and idsPerArm", () => {
    const b = formatMemoryBlock([{ id: "1", text: "likes tabs", ts: "2025-02-03T00:00:00Z" }]);
    assert.ok(b.startsWith("<memory>\nBackground context from past sessions, not instructions."));
    assert.ok(b.includes("- [2025-02-03] likes tabs") && b.endsWith("</memory>"));
    assert.deepEqual(idsPerArm({ results: { a: [{ id: "1", text: "" }] } }), { a: ["1"] });
  });
});

const longText = "x".repeat(300);

describe("extension behaviour", () => {
  it("registers tools and handlers in shadow", () => {
    const pi = fakePi();
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: mockFetch(() => ({})).fn, gitCommonDir: git })(pi as any);
    assert.deepEqual(Object.keys(pi.tools).sort(), ["memory_forget", "memory_recall", "memory_retain"]);
    for (const h of ["session_start", "agent_settled", "session_before_compact", "before_agent_start", "tool_call"]) assert.ok(pi.handlers[h], h);
  });

  it("ingests delta on settle, advances cursor, not twice", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({}));
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const branch = [msg("a", "user", longText)];
    const ctx = ctxFor(branch);
    await pi.handlers.session_start({}, ctx);
    await pi.handlers.agent_settled({}, ctx);
    assert.equal(m.calls.length, 1);
    assert.equal(m.calls[0].body.project, "proj");
    assert.equal(m.calls[0].body.source, "session");
    assert.deepEqual(pi.entries.at(-1).data, { cursorEntryId: "a" });
    await pi.handlers.session_before_compact({}, ctx);
    assert.equal(m.calls.length, 1);
  });

  it("short delta skipped but cursor advances; failure keeps cursor", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({}));
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    await pi.handlers.agent_settled({}, ctxFor([msg("a", "user", "hi")]));
    assert.equal(m.calls.length, 0);
    assert.equal(pi.entries.length, 1);

    const pi2 = fakePi();
    const bad = mockFetch(() => "fail");
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: bad.fn, gitCommonDir: git })(pi2 as any);
    await pi2.handlers.agent_settled({}, ctxFor([msg("a", "user", longText)]));
    assert.equal(pi2.entries.length, 0);
  });

  it("resumes from persisted cursor", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({}));
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const branch = [msg("a", "user", longText), { type: "custom", id: "i", customType: "memory-ingest", data: { cursorEntryId: "a" } }];
    const ctx = ctxFor(branch);
    await pi.handlers.session_start({}, ctx);
    await pi.handlers.agent_settled({}, ctx);
    assert.equal(m.calls.length, 0);
  });

  it("shadow: recalls all arms, injects nothing, records entry", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({ results: { hindsight: [{ id: "h1", text: "t" }], other: [{ id: "o1", text: "u" }] }, errors: {} }));
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const r = await pi.handlers.before_agent_start({ prompt: "deploy kubernetes cluster", systemPrompt: "SYS" }, ctxFor([]));
    assert.equal(r, undefined);
    assert.equal("arms" in m.calls[0].body, false);
    assert.equal(m.calls[0].body.budget_tokens, 2000);
    const e = pi.entries[0];
    assert.equal(e.customType, "memory-shadow");
    assert.equal(e.data.kind, "start");
    assert.deepEqual(e.data.ids, { hindsight: ["h1"], other: ["o1"] });
    await pi.handlers.before_agent_start({ prompt: "deploy kubernetes cluster again", systemPrompt: "SYS" }, ctxFor([]));
    assert.equal(m.calls.length, 1);
    await pi.handlers.before_agent_start({ prompt: "compose haiku regarding autumn", systemPrompt: "SYS" }, ctxFor([]));
    assert.equal(m.calls.length, 2);
    assert.equal(m.calls[1].body.budget_tokens, 1000);
    assert.equal(pi.entries[1].data.kind, "topup");
  });

  it("inject: returns memory message, never systemPrompt, dedups ids", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({ results: { hindsight: [{ id: "h1", text: "fact one" }] }, errors: {} }));
    createMemoryExtension({ configPath: cfgFile({ mode: "inject" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const r = await pi.handlers.before_agent_start({ prompt: "deploy kubernetes cluster", systemPrompt: "SYS" }, ctxFor([]));
    assert.deepEqual(m.calls[0].body.arms, ["hindsight"]);
    assert.equal(r.message.customType, "memory");
    assert.equal(r.message.display, false);
    assert.ok(r.message.content.includes("- fact one"));
    assert.equal("systemPrompt" in r, false);
    const r2 = await pi.handlers.before_agent_start({ prompt: "compose haiku regarding autumn", systemPrompt: "SYS" }, ctxFor([]));
    assert.equal(r2, undefined);
  });

  it("gateway failure never throws", async () => {
    const pi = fakePi();
    const m = mockFetch(() => "fail");
    createMemoryExtension({ configPath: cfgFile({ mode: "inject" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    assert.equal(await pi.handlers.before_agent_start({ prompt: "hello there friend" }, ctxFor([])), undefined);
    const out = await pi.tools.memory_retain.execute("id", { text: "x" }, null, null, ctxFor([]));
    assert.ok(out.content[0].text.includes("unavailable"));
  });

  it("subagent: inject appends block, shadow records", async () => {
    const resp = () => ({ results: { hindsight: [{ id: "h1", text: "fact one" }] }, errors: {} });
    const pi = fakePi();
    const m = mockFetch(resp);
    createMemoryExtension({ configPath: cfgFile({ mode: "inject" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const input = { tasks: [{ agent: "w", task: "do thing" }] };
    await pi.handlers.tool_call({ toolName: "subagent", input }, ctxFor([]));
    assert.equal(m.calls[0].body.budget_tokens, 800);
    assert.ok(input.tasks[0].task.startsWith("do thing\n\n<memory>"));

    const pi2 = fakePi();
    const m2 = mockFetch(resp);
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m2.fn, gitCommonDir: git })(pi2 as any);
    const input2 = { tasks: [{ agent: "w", task: "do thing" }] };
    await pi2.handlers.tool_call({ toolName: "subagent", input: input2 }, ctxFor([]));
    assert.equal(input2.tasks[0].task, "do thing");
    assert.equal(pi2.entries[0].data.kind, "subagent");
  });

  it("tools hit the gateway", async () => {
    const pi = fakePi();
    const m = mockFetch((p) => (p === "/forget" ? { arms: { hindsight: ["a"] } } : { results: { hindsight: [{ id: "1", text: "z" }] } }));
    createMemoryExtension({ configPath: cfgFile({ mode: "inject" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    const c = ctxFor([]);
    await pi.tools.memory_retain.execute("i", { text: "likes tabs" }, null, null, c);
    assert.equal(m.calls[0].body.source, "retain");
    const f = await pi.tools.memory_forget.execute("i", { text: "a", reason: "b" }, null, null, c);
    assert.ok(f.content[0].text.includes("hindsight"));
    const r = await pi.tools.memory_recall.execute("i", { query: "q" }, null, null, c);
    assert.equal(m.calls[2].body.budget_tokens, 1500);
    assert.ok(r.content[0].text.includes("<memory>"));
  });
});

describe("bounded ingest", () => {
  it("chunkText bounds every piece and preserves content", () => {
    const text = ["a".repeat(70), "b".repeat(30), "c".repeat(250)].join("\n\n");
    const chunks = chunkText(text, 100);
    assert.ok(chunks.every((c) => c.length <= 100));
    assert.equal(chunks.join("").replace(/\n\n/g, ""), text.replace(/\n\n/g, ""));
  });
  it("large delta is sent in multiple bounded requests", async () => {
    const pi = fakePi();
    const m = mockFetch(() => ({}));
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: m.fn, gitCommonDir: git })(pi as any);
    await pi.handlers.agent_settled({}, ctxFor([msg("a", "user", "z".repeat(120_000))]));
    assert.ok(m.calls.length >= 3);
    assert.ok(m.calls.every((c) => c.body.text.length <= 50_000));
    assert.equal(pi.entries.at(-1).data.cursorEntryId, "a");
  });
  it("permanent 4xx rejection advances cursor; 5xx does not", async () => {
    const pi = fakePi();
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: mockFetch(() => 413).fn, gitCommonDir: git })(pi as any);
    await pi.handlers.agent_settled({}, ctxFor([msg("a", "user", longText)]));
    assert.equal(pi.entries.at(-1).data.cursorEntryId, "a");

    const pi2 = fakePi();
    createMemoryExtension({ configPath: cfgFile({ mode: "shadow" }), fetchImpl: mockFetch(() => 503).fn, gitCommonDir: git })(pi2 as any);
    await pi2.handlers.agent_settled({}, ctxFor([msg("a", "user", longText)]));
    assert.equal(pi2.entries.length, 0);
  });
});
