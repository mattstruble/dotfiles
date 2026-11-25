import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// guardrails — Pi extension
// Deterministic safety rules the model cannot skip:
// secret scanning, doom loop breaker, force-push block, commit format, staged diff scan.

const SECRET_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /AKIA[0-9A-Z]{16}/, label: "AWS Access Key" },
  { re: /ghp_[A-Za-z0-9_]{36,}/, label: "GitHub PAT" },
  { re: /gho_[A-Za-z0-9_]{36,}/, label: "GitHub OAuth" },
  { re: /(?<![A-Za-z0-9_])(?:[sr]k_|sk-)live_[A-Za-z0-9]+/, label: "Stripe live key" },
  { re: /(?<![A-Za-z0-9_])(?:[sr]k_|sk-)test_[A-Za-z0-9]+/, label: "Stripe test key" },
  { re: /xoxb-[A-Za-z0-9-]+/, label: "Slack bot token" },
  { re: /xoxp-[A-Za-z0-9-]+/, label: "Slack user token" },
  { re: /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/, label: "Private key" },
  { re: /postgres(ql)?:\/\/[^\s]+/, label: "PostgreSQL URI" },
  { re: /mysql:\/\/[^\s]+/, label: "MySQL URI" },
  { re: /mongodb(\+srv)?:\/\/[^\s]+/, label: "MongoDB URI" },
];

// A URI whose userinfo is exactly a redaction placeholder (what redactSecrets emits) holds no secret; drop the
// `scheme://[REDACTED:...]@` prefix so a model copying redacted tool output is not blocked.
const REDACTED_URI_PREFIX = /(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?):\/\/\[REDACTED:[^\]\n]*\]@/g;

export function scanSecrets(text: string): string | null {
  const scanned = text.replace(REDACTED_URI_PREFIX, "");
  for (const { re, label } of SECRET_PATTERNS) {
    if (re.test(scanned)) return label;
  }
  return null;
}

// ── Output redaction (tool results) ────────────────────────────────────────
// Every pattern has a fixed prefix or key; no unanchored high-entropy matching, so git SHAs and digests pass.
// Redaction-only variants: private keys match the whole block; URIs redact only the userinfo.
// URI rule follows gitleaks' generic URL-credentials approach and RFC 3986 section 3.2: userinfo cannot contain
// / ? # or whitespace/quotes, so it ends at the first @ before any of those. Only the userinfo is replaced
// (scheme://[REDACTED:label]@host/path keeps host and path readable and minified JSON intact). A URI without
// userinfo is not a secret and is left unchanged; `h/db,x@y` is path text, not userinfo.
const uriRedaction = (scheme: string) => new RegExp(`(?<=${scheme}:\\/\\/)[^\\s"'<>/?#@]+(?=@)`, "g");
const AWS_SECRET_KEY_NAME = `aws[_-]?secret[_-]?access[_-]?key`;
const REDACT_OVERRIDES: Record<string, RegExp> = {
  "PostgreSQL URI": uriRedaction("postgres(?:ql)?"),
  "MySQL URI": uriRedaction("mysql"),
  "MongoDB URI": uriRedaction("mongodb(?:\\+srv)?"),
  "Private key": new RegExp(
    "-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----(?:[\\s\\S]*?-----END (?:[A-Z]+ )*PRIVATE KEY-----)?",
    "g",
  ),
};
const REDACT_PATTERNS: Array<{ re: RegExp; label: string }> = [
  ...SECRET_PATTERNS.map(({ re, label }) => ({ re: REDACT_OVERRIDES[label] ?? new RegExp(re.source, "g"), label })),
  { re: /ASIA[0-9A-Z]{16}/g, label: "AWS Temporary Access Key" },
  { re: /github_pat_[A-Za-z0-9_]{20,}/g, label: "GitHub fine-grained PAT" },
  { re: /ghs_[A-Za-z0-9]{30,}/g, label: "GitHub App token" },
  { re: /sk-ant-[A-Za-z0-9_-]{20,}/g, label: "Anthropic API key" },
  { re: /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, label: "JWT" },
  // Key-name forms follow gitleaks/detect-secrets keyword rules (no unanchored high-entropy match): the name in
  // snake/kebab/camel/Pascal case (case-insensitive), then `=`, `:`, `=>` (Ruby hash rocket), or whitespace after a
  // `--` CLI flag; optional quotes around key and value; the value stops at a closing quote or delimiter.
  {
    re: new RegExp(
      `(?:--${AWS_SECRET_KEY_NAME}\\s+|${AWS_SECRET_KEY_NAME}["']?\\s*(?:=>|[=:])\\s*)["']?[^\\s"'<>,;)]+`,
      "gi",
    ),
    label: "AWS Secret Key",
  },
];

export type EnvSecret = { name: string; value: string };

const ENV_SECRET_NAME = /(_API_KEY|_TOKEN|_SECRET|_SECRET_ACCESS_KEY|_ACCESS_KEY)$|PASSWORD/;
const ENV_NON_SECRET_NAME = /^MAX_|_MAX_/; // MAX_THINKING_TOKENS, *_MAX_OUTPUT_TOKENS

/** Environment variables whose exact values must never reach the transcript. Longest values first. */
export function loadEnvSecrets(env: Record<string, string | undefined>): EnvSecret[] {
  const out: EnvSecret[] = [];
  for (const [name, value] of Object.entries(env)) {
    if (value === undefined || value.length < 8) continue;
    if (!ENV_SECRET_NAME.test(name) || ENV_NON_SECRET_NAME.test(name)) continue;
    out.push({ name, value });
  }
  return out.sort((a, b) => b.value.length - a.value.length);
}

/** Replace env values and known secret patterns in text with [REDACTED:<label>]. */
export function redactSecrets(text: string, envSecrets: EnvSecret[] = []): string {
  let out = text;
  for (const { name, value } of envSecrets) out = out.split(value).join(`[REDACTED:env:${name}]`);
  for (const { re, label } of REDACT_PATTERNS) out = out.replace(re, `[REDACTED:${label}]`);
  return out;
}

function redactJson(v: any, envSecrets: EnvSecret[]): any {
  if (typeof v === "string") return redactSecrets(v, envSecrets);
  if (Array.isArray(v)) return v.map((x) => redactJson(x, envSecrets));
  if (v && typeof v === "object") {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, redactJson(x, envSecrets)]));
  }
  return v;
}

/**
 * Redact text parts of a tool result (and structuredContent, which pi drops when only content is replaced).
 * Returns a partial patch, or undefined when nothing changed.
 */
export function redactToolResult(
  event: { content?: any[]; structuredContent?: unknown },
  envSecrets: EnvSecret[],
): { content: any[]; structuredContent?: any } | undefined {
  let changed = false;
  const content = (event.content ?? []).map((part) => {
    if (part?.type !== "text" || typeof part.text !== "string") return part;
    const text = redactSecrets(part.text, envSecrets);
    if (text === part.text) return part;
    changed = true;
    return { ...part, text };
  });
  let structured: any;
  if (event.structuredContent !== undefined) {
    const before = JSON.stringify(event.structuredContent);
    structured = redactJson(event.structuredContent, envSecrets);
    if (JSON.stringify(structured) !== before) changed = true;
  }
  if (!changed) return undefined;
  return event.structuredContent !== undefined ? { content, structuredContent: structured } : { content };
}

// ── Unanswered permission prompts ──────────────────────────────────────────
// pi-permission-system blocks a timed-out ask with a tool_call reason. A blocked call skips tool_result, so
// the text only reaches the model as an error toolResult message; the `context` hook is the one place that
// sees and can change it, in the parent and in every child session that runs the tool.
// Shape of renderUnansweredDenial, @gotgenes/pi-permission-system src/presentation/agent-renderer.ts:265, via tagged() :283.
// Anchored to the start of the text: tagged() always puts `[pi-permission-system] ` first, so bash stderr or a
// user's denial reason that merely contains the phrase is left alone. The sentence is a single line (a reason
// may follow it and span lines), hence [^\n]*? rather than the dotall wildcard.
export const UNANSWERED_DENIAL_RE =
  /^\[pi-permission-system\] Nobody\b[^\n]*?\banswered the approval prompt for this\b[^\n]*?\bwithin \d+(\.\d+)?s\./;
export const DEFERRED_DENIAL_TEXT =
  "Deferred: no human available. Do not attempt this another way. Report it as pending under 'Needs approval'.";

/** Replace unanswered-prompt denial text in error tool results. Returns undefined when nothing changed. */
export function deferUnansweredDenials(messages: any[]): any[] | undefined {
  let changed = false;
  const out = messages.map((m) => {
    if (m?.role !== "toolResult" || m.isError !== true || !Array.isArray(m.content)) return m;
    let hit = false;
    const content = m.content.map((part: any) => {
      if (part?.type !== "text" || typeof part.text !== "string" || !UNANSWERED_DENIAL_RE.test(part.text)) return part;
      hit = true;
      return { ...part, text: DEFERRED_DENIAL_TEXT };
    });
    if (!hit) return m;
    changed = true;
    return { ...m, content };
  });
  return changed ? out : undefined;
}

// Process-scoped doom loop history (not persisted across restarts)
const recentCommands: string[] = [];

type GuardResult = { block: true; reason: string; terminate?: boolean } | undefined;

/** bd global flags that consume the following token. */
const BD_VALUE_FLAGS = new Set(["--db", "--actor", "--dolt-auto-commit"]);

/**
 * Return the bd verb of every command segment that invokes bd.
 * ponytail: gaps accepted — `sh -c`/`bash -c` strings, subshell parentheses, and
 * quote-unaware splitting (`bd q "a; bd init"` is blocked as a false positive).
 */
export function bdVerbs(command: string): string[] {
  const verbs: string[] = [];
  for (const segment of command.split(/&&|\|\||[;|\n]/)) {
    const t = segment.trim().split(/\s+/).filter(Boolean);
    let i = 0;
    for (;;) {
      if (i < t.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(t[i])) i++;
      else if (t[i] === "command") i++;
      else if (t[i] === "env") {
        i++;
        while (i < t.length && (t[i].startsWith("-") || /^[A-Za-z_][A-Za-z0-9_]*=/.test(t[i]))) {
          i += t[i] === "-u" || t[i] === "--unset" ? 2 : 1;
        }
      } else break;
    }
    if (i >= t.length || t[i].split("/").pop() !== "bd") continue;
    i++;
    while (i < t.length && t[i].startsWith("-")) i += BD_VALUE_FLAGS.has(t[i]) ? 2 : 1;
    if (i < t.length) verbs.push(t[i]);
  }
  return verbs;
}

/** Reason to block a bash command that runs bd init/setup, else undefined. */
export function bdInitBlockReason(command: string): string | undefined {
  const verbs = bdVerbs(command);
  if (verbs.includes("init") || verbs.includes("setup")) {
    return "bd creates each repo's tracker automatically (bd_store) on the first bd write; never run bd init or bd setup.";
  }
  return undefined;
}

const QUOTED = /'[^']*'|"(?:[^"\\]|\\.)*"/g;
const SHELL_TARGET = /(^|[\s;&|(])(bash|sh|zsh|dash|ssh|eval)(\s|$)/;

/**
 * Drop text the shell never runs: single-quoted strings, double-quoted strings without substitutions,
 * and bodies of quoted-delimiter heredocs (<<'EOF') not fed to a shell. Errs toward keeping text.
 */
function executedText(command: string): string {
  const unquote = (t: string) => t.replace(QUOTED, (q) => (q[0] === '"' && /\$\(|`/.test(q) ? q : "''"));
  const lines = command.split("\n");
  const kept: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    kept.push(unquote(lines[i]));
    const m = lines[i].match(/(?<!<)<<(?!<)-?\s*(['"])(\w+)\1/);
    if (!m || SHELL_TARGET.test(unquote(lines[i].slice(0, m.index)))) continue;
    const end = lines.findIndex((l, j) => j > i && l.replace(/^\t+/, "") === m[2]);
    if (end > 0) i = end; // unterminated bodies are kept and scanned
  }
  return kept.join("\n");
}

const SECRET_PRINT = [
  /(^|[\s;&|(])sops\s+(?:[^|;&\n]*\s)?(-d|--decrypt|decrypt|exec-env|exec-file)(\s|$)/,
  /(^|[\s;&|(])op\s+(?:-[^|;&\n]*\s)?(read|inject)(\s|$)/,
  /(^|[\s;&|(])op\s+[^|;&\n]*--reveal(\s|$)/,
];

/** Reason to block a bash command that would print decrypted secrets into the session, else undefined. */
export function secretDecryptBlockReason(command: string): string | undefined {
  // shortcut: regex over executed text; `bash -c '...'` strings, aliases and eval'd variables are accepted gaps.
  let text: string;
  try {
    text = executedText(command);
  } catch {
    text = command; // fail closed: scan the raw command
  }
  if (SECRET_PRINT.some((re) => re.test(text))) {
    return "Decrypted secrets would enter the session. sops keeps key names in plaintext, so read the encrypted file instead.";
  }
  return undefined;
}

const GIT_PUSH_SEGMENT = /^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*git(?:\s+-[cC]\s+\S+|\s+--[A-Za-z][\w-]*(?:=\S+)?|\s+-P)*\s+push(?:\s+(.*))?$/;
const FORCE_FLAG = /(^|\s)(-[a-zA-Z]*f[a-zA-Z]*|--force(?:-with-lease|-if-includes)?(?:=\S*)?|\+\S+)(?=\s|$)/;

/**
 * Whether a `git push` segment carries a force flag or a `+` refspec. Only the push segment is checked,
 * so a `-f` elsewhere on the line (`--body-file`, a quoted commit message) does not count.
 * ponytail: quote-unaware segment split; `sh -c 'git push -f'` and git aliases are accepted gaps.
 */
export function isForcePush(command: string): boolean {
  return command
    .split(/&&|\|\||[;|\n]/)
    .map((s) => s.trim().replace(/^[({]\s*/, ""))
    .some((s) => {
      const m = s.match(GIT_PUSH_SEGMENT);
      return m !== null && FORCE_FLAG.test(m[1] ?? "");
    });
}

/** Shared bash-command guards: force-push, doom loop, secret decrypt, conventional commit, staged diff secrets, bd remember secrets. */
async function checkBashCommand(cmd: string, pi: ExtensionAPI): Promise<GuardResult> {
  // ── Doom loop breaker ──────────────────────────────────────────────────
  if (recentCommands.length === 3 && recentCommands.every((c) => c === cmd)) {
    return {
      block: true,
      terminate: true,
      reason: "Doom loop detected: same bash command repeated 3 times in a row. Try a different approach.",
    };
  }
  if (recentCommands.length === 3) recentCommands.shift();
  recentCommands.push(cmd);

  // ── Force-push block ───────────────────────────────────────────────────
  if (isForcePush(cmd)) {
    return { block: true, reason: "Force-push is blocked. Use a regular push or open a PR." };
  }

  // ── bd init / setup block ──────────────────────────────────────────────
  const bdReason = bdInitBlockReason(cmd);
  if (bdReason) return { block: true, reason: bdReason };

  // ── Secret decrypt block ───────────────────────────────────────────────
  const secretReason = secretDecryptBlockReason(cmd);
  if (secretReason) return { block: true, reason: secretReason };

  // ── Conventional commit format enforcement ─────────────────────────────
  const commitMsgMatch = cmd.match(/git\s+commit\s+.*-m\s+["'](.+?)["']/);
  if (commitMsgMatch) {
    const msg = commitMsgMatch[1];
    if (!msg.startsWith("Merge")) {
      const CONVENTIONAL =
        /^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .{1,72}$/;
      if (!CONVENTIONAL.test(msg)) {
        return {
          block: true,
          reason:
            `Commit message does not follow conventional commits format.\n` +
            `Expected: ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\\(.+\\))?!?: .{1,72}$\n` +
            `Actual:   ${msg}`,
        };
      }
    }
  }

  // ── Secret scan: staged diff before git commit ─────────────────────────
  if (/git\s+commit/.test(cmd)) {
    let diff = "";
    try {
      const result = await pi.exec("git", ["diff", "--cached"]);
      diff = result.stdout ?? "";
    } catch {
      // Not a repo or no staged changes — skip
    }
    const hit = scanSecrets(diff);
    if (hit) {
      return {
        block: true,
        reason: `Secret detected in staged changes (${hit}). Unstage the file before committing.`,
      };
    }
  }

  // ── bd remember secret guard ───────────────────────────────────────────
  if (/bd\s+remember/.test(cmd)) {
    const hit = scanSecrets(cmd);
    if (hit) {
      return {
        block: true,
        reason: `Secret detected in bd remember command (${hit}). Do not store secrets in beads memory.`,
      };
    }
  }

  return undefined;
}

/** Extract then_run.command from an edit/write tool_call input, if present. */
function getThenRunCommand(input: unknown): string | null {
  const cmd = (input as any)?.then_run?.command;
  return typeof cmd === "string" ? cmd : null;
}

type ToolHints = { readOnlyHint?: boolean; destructiveHint?: boolean };

// Known read-only MCP tools on servers that declare no annotations.
// Full mcp__<server>__<tool> names (pi replaces "-" with "_"), keyed by server.
const READ_ALLOWLIST: Record<string, string[]> = {
  nixos: ["mcp__nixos__nix", "mcp__nixos__nix_versions"],
  pdf_fast: ["mcp__pdf_fast__inspect", "mcp__pdf_fast__outline", "mcp__pdf_fast__read", "mcp__pdf_fast__search"],
};
export const READ_ALLOWLIST_FLAT = Object.values(READ_ALLOWLIST).flat();

/**
 * MCP write gate: approval needed unless allowlisted or readOnlyHint is true.
 * Missing hints count as a write (MCP default readOnlyHint: false). destructiveHint is
 * ignored: per the MCP spec it is only meaningful when readOnlyHint is false.
 */
export function needsApproval(toolName: string, hints: ToolHints | undefined, allowlist: string[]): boolean {
  if (allowlist.includes(toolName)) return false;
  return hints?.readOnlyHint !== true;
}

export const MCP_PROMPT_EVENT = "guardrails:mcp_prompt";
export const MCP_DECISION_EVENT = "guardrails:mcp_decision";
const APPROVE_ONCE = "Yes, once";
const DENY = "No";

/**
 * Split `mcp__<server>__<tool>`; null when the name has no server segment or more than
 * one `__` boundary, since then the server cannot be told apart from the tool.
 */
export function parseMcpTool(name: string): { server: string; tool: string } | null {
  const m = /^mcp__(.+?)__(.+)$/.exec(name);
  if (!m || m[2].includes("__")) return null;
  return { server: m[1], tool: m[2] };
}

type Select = (title: string, options: string[], signal?: AbortSignal) => Promise<string | undefined>;

/**
 * MCP approval prompts with session grants (one tool, or every write on a server).
 * Prompts run one at a time so a codemode fan-out asks once per decision: each queued
 * prompt re-checks grants when it reaches the front. reset() starts a new session;
 * a request queued under an older session is denied without a prompt. Only an exact
 * approve label approves; anything else denies.
 */
export function createMcpGate(emit: (channel: string, data: unknown) => void) {
  const tools = new Set<string>();
  const servers = new Set<string>();
  let generation = 0;
  let chain: Promise<unknown> = Promise.resolve();
  const safeEmit = (channel: string, data: unknown) => {
    try {
      emit(channel, data);
    } catch {
      // a listener failure must not skip the decision event or the prompt
    }
  };

  return {
    reset(): void {
      tools.clear();
      servers.clear();
      generation++;
    },
    request(name: string, summary: string, select: Select, signal?: AbortSignal): Promise<boolean> {
      const server = parseMcpTool(name)?.server;
      const gen = generation;
      const run = async (): Promise<boolean> => {
        if (gen !== generation || signal?.aborted) return false;
        if (tools.has(name) || (server !== undefined && servers.has(server))) return true;
        const toolOption = `Yes, ${name} for this session`;
        const serverOption = server ? `Yes, all ${server} writes for this session` : undefined;
        const options = [APPROVE_ONCE, toolOption, ...(serverOption ? [serverOption] : []), DENY];
        let choice: string | undefined;
        safeEmit(MCP_PROMPT_EVENT, { tool: name });
        try {
          choice = await select(`Allow MCP write tool?\n${name}\n${summary}`, options, signal);
        } catch {
          choice = undefined;
        } finally {
          safeEmit(MCP_DECISION_EVENT, { tool: name });
        }
        if (gen !== generation || signal?.aborted) return false;
        if (choice === toolOption) tools.add(name);
        if (serverOption !== undefined && choice === serverOption) servers.add(server!);
        return choice === APPROVE_ONCE || choice === toolOption || (serverOption !== undefined && choice === serverOption);
      };
      const result = chain.then(run, run);
      chain = result.catch(() => undefined);
      return result;
    },
  };
}

// Tools whose progress UI only renders for direct calls; a codemode script calling them hides it.
const DIRECT_ONLY_TOOLS = new Set(["workflow", "subagent"]);

/** Block direct-only tools when another tool (e.g. codemode) issued the call. */
export function nestedCallReason(toolName: string, parentToolCallId: string | undefined): string | undefined {
  if (!parentToolCallId || !DIRECT_ONLY_TOOLS.has(toolName)) return undefined;
  return `Call \`${toolName}\` directly as a tool, not from codemode or another tool: nested calls hide its progress in the TUI.`;
}

export default function (pi: ExtensionAPI) {
  const mcpGate = createMcpGate((channel, data) => pi.events.emit(channel, data));
  let envSecrets: EnvSecret[] = loadEnvSecrets(process.env);
  pi.on("session_start", async () => {
    mcpGate.reset();
    envSecrets = loadEnvSecrets(process.env);
  });

  // Runs for nested (codemode) calls too: parentToolCallId is deliberately not checked.
  pi.on("tool_result", async (event) => redactToolResult(event as any, envSecrets));

  pi.on("context", async (event) => {
    const messages = deferUnansweredDenials((event as any).messages ?? []);
    return messages ? { messages } : undefined;
  });

  pi.on("tool_call", async (event, ctx) => {
    const tool = event.toolName;
    const input = event.input as Record<string, string>;

    const nested = nestedCallReason(tool, event.parentToolCallId);
    if (nested) return { block: true, reason: nested };

    // ── MCP write gate ─────────────────────────────────────────────────────
    if (tool.startsWith("mcp__")) {
      const hints = pi.getAllTools().find((t) => t.name === tool)?.annotations;
      if (needsApproval(tool, hints, READ_ALLOWLIST_FLAT)) {
        if (!ctx.hasUI) {
          return { block: true, reason: "MCP write tools need interactive confirmation; ask the user in the main session" };
        }
        const args = JSON.stringify(event.input ?? {});
        const summary = args.length > 200 ? `${args.slice(0, 200)}…` : args;
        if (!(await mcpGate.request(tool, summary, (title, options, signal) => ctx.ui.select(title, options, { signal }), ctx.signal))) {
          return { block: true, reason: `${tool} was not approved by the user` };
        }
      }
      return;
    }

    // ── Secret scan: write / edit ──────────────────────────────────────────
    if (tool === "write") {
      const hit = scanSecrets(input.content ?? "");
      if (hit) {
        return { block: true, reason: `Secret detected in write (${hit}): ${input.filePath}` };
      }
    }

    if (tool === "edit") {
      const hit = scanSecrets(input.newString ?? "");
      if (hit) {
        return { block: true, reason: `Secret detected in edit (${hit}): ${input.filePath}` };
      }
    }

    // ── Bash guards: direct bash calls ─────────────────────────────────────
    if (tool === "bash") {
      return checkBashCommand(input.command ?? "", pi);
    }

    // ── Bash guards: fused then_run.command on edit/write (Action Fusion) ─
    if (tool === "edit" || tool === "write") {
      const fusedCmd = getThenRunCommand(event.input);
      if (fusedCmd) {
        return checkBashCommand(fusedCmd, pi);
      }
    }
  });
}
