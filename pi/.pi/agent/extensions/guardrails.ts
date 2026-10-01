import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// guardrails — Pi extension
// Deterministic safety rules the model cannot skip:
// secret scanning, doom loop breaker, force-push block, commit format, staged diff scan.

const SECRET_PATTERNS: Array<{ re: RegExp; label: string }> = [
  { re: /AKIA[0-9A-Z]{16}/, label: "AWS Access Key" },
  { re: /ghp_[A-Za-z0-9_]{36,}/, label: "GitHub PAT" },
  { re: /gho_[A-Za-z0-9_]{36,}/, label: "GitHub OAuth" },
  { re: /sk-live_[A-Za-z0-9]+/, label: "Stripe live key" },
  { re: /sk-test_[A-Za-z0-9]+/, label: "Stripe test key" },
  { re: /xoxb-[A-Za-z0-9-]+/, label: "Slack bot token" },
  { re: /xoxp-[A-Za-z0-9-]+/, label: "Slack user token" },
  { re: /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/, label: "Private key" },
  { re: /postgres(ql)?:\/\/[^\s]+/, label: "PostgreSQL URI" },
  { re: /mysql:\/\/[^\s]+/, label: "MySQL URI" },
  { re: /mongodb(\+srv)?:\/\/[^\s]+/, label: "MongoDB URI" },
];

function scanSecrets(text: string): string | null {
  for (const { re, label } of SECRET_PATTERNS) {
    if (re.test(text)) return label;
  }
  return null;
}

// Process-scoped doom loop history (not persisted across restarts)
const recentCommands: string[] = [];

type GuardResult = { block: true; reason: string; terminate?: boolean } | undefined;

/** Shared bash-command guards: force-push, doom loop, conventional commit, staged diff secrets, bd remember secrets. */
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
  if (/git\s+push\s+.*(-f|--force|--force-with-lease)/.test(cmd) || /\+refs\//.test(cmd)) {
    return { block: true, reason: "Force-push is blocked. Use a regular push or open a PR." };
  }

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

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const tool = event.toolName;
    const input = event.input as Record<string, string>;

    // ── MCP write gate ─────────────────────────────────────────────────────
    if (tool.startsWith("mcp__")) {
      const hints = pi.getAllTools().find((t) => t.name === tool)?.annotations;
      if (needsApproval(tool, hints, READ_ALLOWLIST_FLAT)) {
        if (!ctx.hasUI) {
          return { block: true, reason: "MCP write tools need interactive confirmation; ask the user in the main session" };
        }
        const args = JSON.stringify(event.input ?? {});
        const summary = args.length > 200 ? `${args.slice(0, 200)}…` : args;
        if (!(await ctx.ui.confirm("Allow MCP write tool?", `${tool}\n${summary}`))) {
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
