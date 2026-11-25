import { it } from "node:test";
import * as assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import {
  bdInitBlockReason,
  secretDecryptBlockReason,
  bdVerbs,
  default as guardrails,
  loadEnvSecrets,
  redactSecrets,
  scanSecrets,
  createMcpGate,
  DEFERRED_DENIAL_TEXT,
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

it("blocks commands that print decrypted secrets", () => {
  for (const c of [
    "sops --decrypt secrets.yaml",
    "sops -d hosts/x/secrets.yaml | head",
    "cd nix && sops --output-type json -d s.yaml",
    "op read op://vault/item/field",
    "X=$(op read op://v/i/f)",
    'X="$(op read op://v/i/f)"',
    "cat <<< hi\nsops -d s.yaml",
    "echo $((1 << 2))\nsops -d s.yaml",
    "echo \"it's\"; sops -d s.yaml; echo 'x'",
    "cat <<EOF\n$(op read x)\nEOF",
    "bash <<'EOF'\nsops -d x\nEOF",
    "cat <<'EOF'\nunterminated\nsops -d x",
    "sops decrypt s.yaml",
    "sops exec-env s.yaml env",
    "op --account a read op://v/i/f",
    "op inject -i tpl",
    "op item get x --reveal",
  ]) {
    assert.match(secretDecryptBlockReason(c) ?? "", /Decrypted secrets would enter the session/, c);
  }
});

it("allows sops and op commands that do not decrypt", () => {
  for (const c of ["sops --encrypt s.yaml", "sops updatekeys s.yaml", "grep -n sops nix/modules/sops.nix", "op whoami", "cat sops.yaml", "echo 'op read is blocked'", 'bd create -d "blocks sops --decrypt"',
    "python3 - <<'EOF'\nprint('sops -d x')\nEOF\nls", "cat <<-'EOF'\n\tsops -d x\n\tEOF\nls", "x".repeat(1_000_000)]) {
    assert.equal(secretDecryptBlockReason(c), undefined, c);
  }
});

const AKIA_KEY = "AK" + "IA" + "ABCDEFGHIJKLMNOP";
const PEM_BEGIN = "-----" + "BEGIN RSA PRIVATE KEY" + "-----";
const PEM_END = "-----" + "END RSA PRIVATE KEY" + "-----";
const PATTERN_CASES: Array<[string, string]> = [
  [AKIA_KEY, "AWS Access Key"],
  ["AS" + "IA" + "ABCDEFGHIJKLMNOP", "AWS Temporary Access Key"],
  ["ghp_" + "a".repeat(36), "GitHub PAT"],
  ["gho_" + "b".repeat(36), "GitHub OAuth"],
  ["github_pat_" + "c1_".repeat(10), "GitHub fine-grained PAT"],
  ["ghs_" + "d".repeat(30), "GitHub App token"],
  ["sk-ant-" + "api03-abcDEF_123-".repeat(2), "Anthropic API key"],
  ["sk-" + "live_abc123", "Stripe live key"],
  ["sk-" + "test_abc123", "Stripe test key"],
  ["sk_" + "live_abc123", "Stripe live key"],
  ["sk_" + "test_abc123", "Stripe test key"],
  ["rk_" + "live_abc123", "Stripe live key"],
  ["xo" + "xb-123-abc", "Slack bot token"],
  ["xo" + "xp-123-abc", "Slack user token"],
  [PEM_BEGIN, "Private key"],
  [PEM_BEGIN + "\nbody-line-1\nbody-line-2\n" + PEM_END, "Private key"],
  ["post" + "gres://u:p@h/db", "PostgreSQL URI", "post" + "gres://[REDACTED:PostgreSQL URI]@h/db"],
  ["my" + "sql://u:p@h/db", "MySQL URI", "my" + "sql://[REDACTED:MySQL URI]@h/db"],
  ["mongo" + "db+srv://u:p@h/db", "MongoDB URI", "mongo" + "db+srv://[REDACTED:MongoDB URI]@h/db"],
  ["ey" + "JhbGciOiJIUzI1NiJ9." + "ey" + "JzdWIiOiIxMjM0In0.abc_DEF-123", "JWT"],
  ["aws_secret_" + "access_key = wJalrXUtnFEMI/K7MDENG", "AWS Secret Key"],
];
const ENV_VALUE = "hunter2-very-secret";

type Handler = (event: any, ctx?: any) => Promise<any> | any;
function loadHandlers(): Record<string, Handler> {
  const handlers: Record<string, Handler> = {};
  guardrails({ on: (n: string, h: Handler) => (handlers[n] = h), events: { emit() {} }, getAllTools: () => [] } as any);
  return handlers;
}

it("redacts every pattern in bash, read and MCP tool results", async () => {
  process.env.TEST_GUARD_API_KEY = ENV_VALUE;
  const h = loadHandlers();
  await h.session_start({});
  delete process.env.TEST_GUARD_API_KEY;
  for (const toolName of ["bash", "read", "mcp__srv__get"]) {
    for (const [secret, label, expected] of [...PATTERN_CASES, [ENV_VALUE, "env:TEST_GUARD_API_KEY"]]) {
      const event = {
        type: "tool_result",
        toolName,
        toolCallId: "c1",
        input: {},
        isError: false,
        details: { keep: 1 },
        content: [
          { type: "text", text: `before ${secret} after` },
          { type: "image", data: "x", mimeType: "image/png" },
        ],
      };
      const res = await h.tool_result(event);
      assert.equal(res.content[0].text, `before ${expected ?? `[REDACTED:${label}]`} after`, `${toolName} ${label}`);
      assert.deepEqual(res.content[1], event.content[1]);
      assert.equal(res.details, undefined);
    }
  }
});

it("redacts structuredContent and nested calls with parentToolCallId", async () => {
  const h = loadHandlers();
  const res = await h.tool_result({
    toolName: "mcp__srv__get",
    toolCallId: "p/1",
    parentToolCallId: "p",
    input: {},
    isError: false,
    content: [{ type: "text", text: `key ${AKIA_KEY}` }],
    structuredContent: { a: [AKIA_KEY], n: 1 },
  });
  assert.equal(res.content[0].text, "key [REDACTED:AWS Access Key]");
  assert.deepEqual(res.structuredContent, { a: ["[REDACTED:AWS Access Key]"], n: 1 });
});

it("leaves git SHAs, sha256 digests and clean results unchanged", async () => {
  const sha1 = "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3";
  const sha256 = "sha256:" + "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08";
  const text = `commit ${sha1}\n${sha256}`;
  assert.equal(redactSecrets(text), text);
  const h = loadHandlers();
  assert.equal(await h.tool_result({ toolName: "bash", input: {}, isError: false, content: [{ type: "text", text }] }), undefined);
});

it("loads only secret-named env values of length 8 or more", () => {
  const got = loadEnvSecrets({
    FOO_API_KEY: "abcdefgh",
    GH_TOKEN: "short",
    DB_PASSWORD: "longpassword",
    MY_PASSWORD_FILE: "/run/secrets/x",
    X_SECRET: "12345678",
    MAX_THINKING_TOKENS: "1234567890",
    CLAUDE_CODE_MAX_OUTPUT_TOKENS: "1234567890",
    PATH: "/usr/bin:/bin",
  }).map((e) => e.name);
  assert.deepEqual(got.sort(), ["DB_PASSWORD", "FOO_API_KEY", "MY_PASSWORD_FILE", "X_SECRET"]);
});

// ── sign-unpushed alias (optional manual step) ─────────────────────────────
const ISOLATED_ENV = {
  ...process.env,
  GIT_CONFIG_GLOBAL: "/dev/null",
  GIT_CONFIG_NOSYSTEM: "1",
  GIT_AUTHOR_NAME: "t",
  GIT_AUTHOR_EMAIL: "t@example.com",
  GIT_COMMITTER_NAME: "t",
  GIT_COMMITTER_EMAIL: "t@example.com",
};

function makeSigningRepo() {
  const root = mkdtempSync(join(tmpdir(), "guardrails-sign-"));
  const key = join(root, "key");
  execFileSync("ssh-keygen", ["-q", "-t", "ed25519", "-N", "", "-f", key], { stdio: "ignore" });
  const sign = ["-c", "gpg.format=ssh", "-c", `user.signingkey=${key}`, "-c", "gpg.ssh.program=ssh-keygen"];
  const git = (dir: string, ...args: string[]) =>
    execFileSync("git", args, { cwd: dir, env: ISOLATED_ENV, encoding: "utf8" });
  const remote = join(root, "remote.git");
  const work = join(root, "work");
  git(root, "init", "-q", "--bare", "-b", "main", remote);
  git(root, "init", "-q", "-b", "main", work);
  git(work, "remote", "add", "origin", remote);
  let n = 0;
  const commit = (signed: boolean) => {
    writeFileSync(join(work, "f"), String(++n));
    git(work, "add", "f");
    git(work, ...(signed ? sign : []), "commit", "-q", ...(signed ? ["-S"] : []), "-m", `c${n}`);
  };
  // Run the body of the real `sign-unpushed` alias (from home.nix) with the test signing config.
  const alias = (dir: string) => {
    const spawned = spawnSync("sh", ["-c", signUnpushedBody()], {
      cwd: dir,
      encoding: "utf8",
      env: {
        ...ISOLATED_ENV,
        GIT_CONFIG_COUNT: "3",
        GIT_CONFIG_KEY_0: "gpg.format",
        GIT_CONFIG_VALUE_0: "ssh",
        GIT_CONFIG_KEY_1: "user.signingkey",
        GIT_CONFIG_VALUE_1: key,
        GIT_CONFIG_KEY_2: "gpg.ssh.program",
        GIT_CONFIG_VALUE_2: "ssh-keygen",
      },
    });
    return { status: spawned.status, stderr: spawned.stderr };
  };
  return { root, work, remote, git, sign, commit, alias };
}

function signUnpushedBody(): string {
  const nix = readFileSync(new URL("../../../../nix-darwin/home.nix", import.meta.url), "utf8");
  const m = nix.match(/^\s*sign-unpushed = "!(.*)";$/m);
  assert.ok(m, "sign-unpushed alias not found in home.nix");
  return m[1].replace(/\\(.)/g, "$1"); // undo Nix string escapes
}

it("lets a plain push through but still blocks a forced push", async () => {
  const h = loadHandlers();
  const push = await h.tool_call({ toolName: "bash", input: { command: "git push origin main" } }, { cwd: tmpdir() });
  assert.equal(push, undefined);
  const forced = await h.tool_call({ toolName: "bash", input: { command: "git push --force origin main" } }, { cwd: tmpdir() });
  assert.equal(forced?.block, true);
  assert.match(forced?.reason, /Force-push is blocked/);
});

it("sign-unpushed signs only commits on no remote ref, and refuses over a merge", () => {
  const r = makeSigningRepo();
  try {
    r.commit(true);
    r.git(r.work, "push", "-q", "-u", "origin", "main");
    // Pushed unsigned commit on another branch, then two unsigned local commits on main.
    r.git(r.work, "checkout", "-q", "-b", "other");
    r.commit(false);
    r.git(r.work, "push", "-q", "origin", "other");
    const pushedUnsigned = r.git(r.work, "rev-parse", "HEAD").trim();
    r.git(r.work, "checkout", "-q", "main");
    r.commit(false);
    r.commit(false);
    const mainBase = r.git(r.work, "rev-parse", "HEAD~2").trim();
    const first = r.alias(r.work);
    assert.equal(first.status, 0, first.stderr);
    assert.equal(r.git(r.work, "rev-parse", "HEAD~2").trim(), mainBase); // pushed base untouched
    assert.equal(r.git(r.work, "rev-parse", "other").trim(), pushedUnsigned);
    for (const rev of ["HEAD", "HEAD~1"]) assert.match(r.git(r.work, "cat-file", "commit", rev), /^gpgsig /m);

    // A merge in the unpushed range: non-zero exit, history unchanged.
    r.git(r.work, "checkout", "-q", "-b", "side", "HEAD~1");
    writeFileSync(join(r.work, "g"), "side");
    r.git(r.work, "add", "g");
    r.git(r.work, "commit", "-q", "-m", "side");
    r.git(r.work, "checkout", "-q", "main");
    r.git(r.work, "merge", "-q", "--no-ff", "-m", "Merge side", "side");
    const before = r.git(r.work, "rev-parse", "HEAD");
    const res = r.alias(r.work);
    assert.notEqual(res.status, 0);
    assert.match(res.stderr, /merge/);
    assert.equal(r.git(r.work, "rev-parse", "HEAD"), before);
  } finally {
    rmSync(r.root, { recursive: true, force: true });
  }
});

it("does not treat identifiers like " + "ta" + "sk" + "_test_cases as Stripe keys", async () => {
  const h = loadHandlers();
  await h.session_start({});
  for (const word of ["ta" + "sk" + "_test_cases", "ma" + "s" + "k_live_data", "ri" + "sk" + "_test_x1"]) {
    const w = await h.tool_call({ toolName: "write", input: { filePath: "/tmp/x", content: `x = ${word}` } }, { cwd: "/tmp" });
    assert.equal(w, undefined, word);
    const text = `before ${word} after`;
    assert.equal(redactSecrets(text), text, word);
  }
  // Real keys (built by concatenation) are still caught.
  const key = "sk_" + "test_" + "abcDEF123";
  const blocked = await h.tool_call({ toolName: "write", input: { filePath: "/tmp/x", content: key } }, { cwd: "/tmp" });
  assert.equal(blocked?.block, true);
  assert.equal(redactSecrets(`a ${key} b`), "a [REDACTED:Stripe test key] b");
});

// Fixtures built by hand from the templates in @gotgenes/pi-permission-system
// src/presentation/agent-renderer.ts (node cannot import TypeScript from node_modules). Each line gives the
// template it mirrors. tagged() :283 yields `${EXTENSION_TAG} ${sentence}${reasonClause}` (tag :41, reason :423 =
// ` Reason: ${reason}.`); identification() :300 yields `'<surface>' <callWord> [for tool '<t>'] [for agent '<a>']
// [<rule clause>]`, with askRuleClause() :381 giving `(rule '<pattern>')`.
const TAG = "[pi-permission-system]";
const UNANSWERED = [
  // renderUnansweredDenial :258-266; surface 'bash', agent 'worker', rule 'rm *', 60000 ms.
  `${TAG} Nobody answered the approval prompt for this 'bash' call for agent 'worker' (rule 'rm *') within 60s.`,
  // Same, no agent or rule.
  `${TAG} Nobody answered the approval prompt for this 'bash' call within 60s.`,
  // Same with decidedElsewhere (servingClause :279), tool differing from surface (toolClause), a reason, 12500 ms.
  `${TAG} Nobody in the session serving this request answered the approval prompt for this 'mcp' call for tool 'mcp__srv__do' for agent 'worker' within 12.5s. Reason: because.`,
];
const KEPT = [
  // renderUserDenial :133-141
  `${TAG} The user denied this 'bash' call for agent 'worker' (rule 'rm *'). Reason: no.`,
  // renderPolicyDenial :121-129 (callWord "" is filtered out of identification)
  `${TAG} Denied by policy: 'bash' for agent 'worker' (rule 'rm *').`,
  // renderUnavailableDenial :230-238
  `${TAG} This 'bash' call for agent 'worker' (rule 'rm *') requires approval, but no interactive UI is available.`,
  // renderUserDenial with a denial reason that quotes the unanswered phrase: not at the start of the sentence.
  `${TAG} The user denied this 'bash' call. Reason: Nobody answered the approval prompt for this 'bash' call within 60s.`,
];
const toolResult = (text: string, isError = true) => ({
  role: "toolResult",
  toolCallId: "c1",
  toolName: "bash",
  isError,
  content: [{ type: "text", text }],
});

it("rewrites unanswered-prompt denials in the context hook", async () => {
  const h = loadHandlers();
  for (const text of UNANSWERED) {
    const user = { role: "user", content: "hi" };
    const res = await h.context({ messages: [user, toolResult(text)] });
    assert.equal(res.messages[0], user);
    assert.equal(res.messages[1].content[0].text, DEFERRED_DENIAL_TEXT);
    assert.equal(res.messages[1].toolCallId, "c1");
    assert.equal(res.messages[1].isError, true);
  }
});

it("keeps rule, user and unavailable denials and non-error results unchanged", async () => {
  const h = loadHandlers();
  for (const text of KEPT) assert.equal(await h.context({ messages: [toolResult(text)] }), undefined, text);
  assert.equal(await h.context({ messages: [toolResult(UNANSWERED[0], false)] }), undefined);
});

it("leaves text that contains the unanswered phrase without the leading tag unchanged", async () => {
  const h = loadHandlers();
  const phrase = "Nobody answered the approval prompt for this 'bash' call within 60s.";
  for (const text of [
    phrase,
    `grep: ${phrase}`,
    `bash: stderr line\n${TAG} ${phrase}`,
    ` ${TAG} ${phrase}`,
    `${TAG}  ${phrase}`,
  ]) {
    assert.equal(await h.context({ messages: [toolResult(text)] }), undefined, text);
  }
});

// The templates this extension's rewrite is anchored to still exist in the installed package.
const RENDERER = join(homedir(), ".pi/agent/npm/node_modules/@gotgenes/pi-permission-system/src/presentation/agent-renderer.ts");
it("installed agent-renderer.ts still has the unanswered-denial template and tag", { skip: !existsSync(RENDERER) && "pi-permission-system not installed" }, () => {
  const src = readFileSync(RENDERER, "utf8");
  assert.ok(src.includes("answered the approval prompt for this "), "unanswered template changed");
  assert.ok(src.includes("`Nobody${servingClause("), "unanswered template changed");
  // The tag is built as `[${EXTENSION_ID}]` and put first by tagged(); the id lives in the config module.
  assert.ok(src.includes("EXTENSION_TAG = `[${EXTENSION_ID}]`"), "tag construction changed");
  assert.ok(src.includes("`${EXTENSION_TAG} ${sentence}"), "tagged() no longer puts the tag first");
  const cfg = readFileSync(join(RENDERER, "../../config/extension-config.ts"), "utf8");
  assert.ok(cfg.includes('EXTENSION_ID = "pi-permission-system"'), "extension id changed");
});

it("redacts the value of AWS_SECRET_ACCESS_KEY and AWS_*_ACCESS_KEY env vars", () => {
  const secret = "wJalr" + "XUtnFEMI-K7MDENG-bPxRfiCY";
  const env = { AWS_SECRET_ACCESS_KEY: secret, AWS_ACCESS_KEY_ID: "id-not-matched-by-name", PATH: "/usr/bin" };
  const secrets = loadEnvSecrets(env);
  assert.deepEqual(secrets.map((e) => e.name), ["AWS_SECRET_ACCESS_KEY"]);
  for (const text of [`AWS_SECRET_ACCESS_KEY=${secret}\n`, `export-credentials: ${secret}\n`, `${secret}`]) {
    const out = redactSecrets(text, secrets);
    assert.ok(!out.includes(secret), out);
    assert.match(out, /\[REDACTED:/);
  }
  assert.deepEqual(loadEnvSecrets({ SOME_ACCESS_KEY: "12345678abcd" }).map((e) => e.name), ["SOME_ACCESS_KEY"]);
});

it("stops URI and aws secret key redaction at delimiters", () => {
  const uri = "post" + "gres://u:p@h/db";
  assert.equal(
    redactSecrets(`{"url":"${uri}","name":"svc"}`),
    '{"url":"post' + 'gres://[REDACTED:PostgreSQL URI]@h/db","name":"svc"}',
  );
  assert.ok(redactSecrets(`{"url":"${uri}","name":"svc"}`).endsWith(',"name":"svc"}'));
  assert.equal(redactSecrets(`(${uri}) next`), "(post" + "gres://[REDACTED:PostgreSQL URI]@h/db) next");
  const kv = "aws_secret_" + "access_key=abc123";
  assert.equal(redactSecrets(`{"a":"${kv}","b":1}`), '{"a":"[REDACTED:AWS Secret Key]","b":1}');
});

it("redacts quoted, kwarg, YAML and export forms of the aws secret key", () => {
  const v = "wJalr" + "XUtnFEMI/K7MDENG";
  const name = "aws_secret_" + "access_key";
  const cases = [
    `${name} = "${v}"`,
    `${name} = '${v}'`,
    `client(${name}="${v}")`,
    `${name}: ${v}`,
    `"${name}": "${v}"`,
    `export ${name.toUpperCase()}='${v}'`,
  ];
  for (const text of cases) {
    const out = redactSecrets(text);
    assert.ok(!out.includes(v), out);
    assert.match(out, /\[REDACTED:AWS Secret Key\]/);
  }
});

it("redacts the whole password of a URI with delimiters in the userinfo", () => {
  const uri = "post" + "gres://u:pa,ss@h/db";
  const out = redactSecrets(`url ${uri} end`);
  assert.equal(out, "url post" + "gres://[REDACTED:PostgreSQL URI]@h/db end");
  for (const part of ["pa,", ",ss", "u:"]) assert.ok(!out.includes(part), part);
  const semi = "my" + "sql://u:p;a)s@h/db";
  assert.equal(redactSecrets(`(${semi})`), "(my" + "sql://[REDACTED:MySQL URI]@h/db)");
  assert.ok(!redactSecrets(`(${semi})`).includes("a)s"));
});

it("redacts only the RFC 3986 userinfo and leaves URIs without userinfo unchanged", () => {
  const pg = "post" + "gres://";
  for (const text of [`${pg}h/db,admin@example.com`, `(${pg}h/db),x@y`, `${pg}h:5432/db?u=a@b`, `${pg}h/db#a@b`, `${pg}h/db`]) {
    assert.equal(redactSecrets(text), text);
  }
  assert.equal(redactSecrets(`${pg}u:p@h/db`), `${pg}[REDACTED:PostgreSQL URI]@h/db`);
  assert.equal(redactSecrets(`(${pg}u:p@h:5432/db?x=a@b),z`), `(${pg}[REDACTED:PostgreSQL URI]@h:5432/db?x=a@b),z`);
  assert.equal(redactSecrets(`${pg}u:p@h/db`), redactSecrets(redactSecrets(`${pg}u:p@h/db`)));
});

it("redacts hash-rocket, camelCase, PascalCase and CLI flag forms of the aws secret key", () => {
  const v = "wJalr" + "XUtnFEMI/K7MDENG";
  const snake = "aws_secret_" + "access_key";
  const cases = [
    `:${snake} => "${v}"`,
    `${snake} => '${v}'`,
    `aws` + `SecretAccessKey: "${v}"`,
    `Aws` + `SecretAccessKey: "${v}"`,
    `"Aws` + `SecretAccessKey": "${v}"`,
    `--aws-secret-` + `access-key ${v}`,
    `--aws-secret-` + `access-key=${v}`,
    `--aws-secret-` + `access-key "${v}"`,
    `aws-secret-` + `access-key: ${v}`,
  ];
  for (const text of cases) {
    const out = redactSecrets(text);
    assert.ok(!out.includes(v), out);
    assert.match(out, /\[REDACTED:AWS Secret Key\]/);
  }
  assert.equal(redactSecrets(`run --aws-secret-` + `access-key ${v} --region x`), "run [REDACTED:AWS Secret Key] --region x");
});

it("redacts a full private key block including the body", () => {
  const block = `${PEM_BEGIN}\nMIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu\nline-two-body\n${PEM_END}`;
  assert.equal(redactSecrets(`before\n${block}\nafter`), "before\n[REDACTED:Private key]\nafter");
  assert.equal(redactSecrets(`x\n${PEM_BEGIN}\ntruncated-body`), "x\n[REDACTED:Private key]\ntruncated-body");
});

it("redacts sk_/rk_ Stripe keys", () => {
  for (const k of ["sk_" + "live_abc123XYZ", "rk_" + "live_abc123XYZ", "sk_" + "test_abc123XYZ"]) {
    assert.match(redactSecrets(`k=${k}`), /^k=\[REDACTED:Stripe (live|test) key\]$/);
  }
});

it("scanSecrets ignores URIs whose userinfo is a redaction placeholder", () => {
  for (const [scheme, label] of [["post" + "gres", "PostgreSQL URI"], ["my" + "sql", "MySQL URI"], ["mongo" + "db+srv", "MongoDB URI"]]) {
    assert.equal(scanSecrets(`${scheme}://[REDACTED:${label}]@h/db`), null);
    assert.equal(scanSecrets(`psql "${scheme}://[REDACTED:${label}]@h/db" -c x`), null);
  }
});

it("scanSecrets still catches URIs with real userinfo", () => {
  assert.equal(scanSecrets("post" + "gres://u:p@h/db"), "PostgreSQL URI");
  assert.equal(scanSecrets("my" + "sql://u:p@h/db"), "MySQL URI");
  assert.equal(scanSecrets("mongo" + "db+srv://u:p@h/db"), "MongoDB URI");
  const redacted = "post" + "gres://[REDACTED:PostgreSQL URI]@h/db";
  assert.equal(scanSecrets(`${redacted},post` + "gres://u:p@h/db"), "PostgreSQL URI");
  assert.equal(scanSecrets("post" + "gres://[REDACTED:PostgreSQL URI]x:p@h/db"), "PostgreSQL URI");
});
