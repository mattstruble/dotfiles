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

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    const tool = event.toolName;
    const input = event.input as Record<string, string>;

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

    if (tool !== "bash") return;

    const cmd = input.command ?? "";

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
        diff = await pi.exec("git", ["diff", "--cached"]);
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
  });
}
