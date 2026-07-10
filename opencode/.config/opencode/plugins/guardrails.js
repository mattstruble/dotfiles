// guardrails — OpenCode plugin
// tool.execute.before handler enforcing deterministic rules the model cannot skip:
// doom loop breaker, force-push block, branch guard, commit format, secret scanning.

const SECRET_PATTERNS = [
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

function scanSecrets(text) {
  for (const { re, label } of SECRET_PATTERNS) {
    if (re.test(text)) return label;
  }
  return null;
}

// Module-level doom loop history (process-scoped, not persisted)
const recentCommands = [];

export const GuardrailsPlugin = async ({ $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = input.tool;

      // ── Secret scan: write / edit ────────────────────────────────────────
      if (tool === "write") {
        const hit = scanSecrets(output.args.content ?? "");
        if (hit) throw new Error(`Secret detected in write (${hit}): ${output.args.filePath}`);
      }

      if (tool === "edit") {
        const hit = scanSecrets(output.args.newString ?? "");
        if (hit) throw new Error(`Secret detected in edit (${hit}): ${output.args.filePath}`);
      }

      if (tool !== "bash") return;

      const cmd = output.args.command ?? "";

      // ── Doom loop breaker ────────────────────────────────────────────────
      if (
        recentCommands.length === 3 &&
        recentCommands.every((c) => c === cmd)
      ) {
        throw new Error(
          "Doom loop detected: same bash command repeated 3 times in a row. Try a different approach."
        );
      }
      if (recentCommands.length === 3) recentCommands.shift();
      recentCommands.push(cmd);

      // ── Force-push block ─────────────────────────────────────────────────
      if (/git\s+push\s+.*(-f|--force|--force-with-lease)/.test(cmd) || /\+refs\//.test(cmd)) {
        throw new Error("Force-push is blocked. Use a regular push or open a PR.");
      }

      // ── Branch guard ─────────────────────────────────────────────────────
      if (/git\s+(commit|merge|rebase)/.test(cmd)) {
        let branch = "";
        try {
          branch = (await $`git branch --show-current`.text()).trim();
        } catch {
          // If git isn't available or not a repo, skip the guard
        }
        if (branch === "main" || branch === "master") {
          throw new Error(
            `Cannot commit/merge/rebase on ${branch}. Create a branch first.`
          );
        }
      }

      // ── Commit format enforcement ────────────────────────────────────────
      const commitMsgMatch = cmd.match(/git\s+commit\s+.*-m\s+["'](.+?)["']/);
      if (commitMsgMatch) {
        const msg = commitMsgMatch[1];
        // Pass through merge commits
        if (!msg.startsWith("Merge")) {
          const CONVENTIONAL = /^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: .{1,72}$/;
          if (!CONVENTIONAL.test(msg)) {
            throw new Error(
              `Commit message does not follow conventional commits format.\n` +
              `Expected: ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\\(.+\\))?!?: .{1,72}$\n` +
              `Actual:   ${msg}`
            );
          }
        }
      }

      // ── Secret scan: git commit staged content ───────────────────────────
      if (/git\s+commit/.test(cmd)) {
        let diff = "";
        try {
          diff = await $`git diff --cached`.text();
        } catch {
          // Not a repo or no staged changes — skip
        }
        const hit = scanSecrets(diff);
        if (hit) throw new Error(`Secret detected in staged changes (${hit}). Unstage the file before committing.`);
      }

      // ── bd remember secret guard ─────────────────────────────────────────
      if (/bd\s+remember/.test(cmd)) {
        const hit = scanSecrets(cmd);
        if (hit) throw new Error(`Secret detected in bd remember command (${hit}). Do not store secrets in beads memory.`);
      }
    },
  };
};
