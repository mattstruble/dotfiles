import type { ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

function isPlanModeActive(): boolean {
  return (globalThis as any).__piPlanMode === true;
}

// Commands that are safe for read-only exploration in plan mode.
const READ_ONLY_COMMANDS = new Set([
  "cat", "head", "tail", "less", "more",
  "grep", "rg", "ag",
  "find", "fd", "locate",
  "ls", "eza", "tree", "exa",
  "pwd", "realpath", "dirname", "basename",
  "echo", "printf",
  "wc", "sort", "uniq", "cut", "awk", "sed",
  "diff", "comm",
  "file", "stat", "du", "df",
  "which", "whereis", "type", "command",
  "printenv", "env",
  "uname", "whoami", "id", "date", "uptime",
  "ps", "pgrep",
  "jq", "yq", "bat", "hexdump", "xxd",
  "nix", "nix-instantiate",
  "git",
  "gh",
]);

// Mutating git subcommands that should still be blocked.
const MUTATING_GIT = new Set([
  "push", "commit", "merge", "rebase", "reset", "checkout", "switch",
  "restore", "cherry-pick", "revert", "stash", "pull", "fetch",
  "clean", "rm", "mv", "add", "init", "clone", "worktree",
  "bisect", "am", "apply", "format-patch",
]);

// Mutating gh subcommands that should still be blocked.
const MUTATING_GH = new Set([
  "pr create", "pr merge", "pr close", "pr edit", "pr ready", "pr review",
  "issue create", "issue close", "issue edit", "issue delete",
  "repo create", "repo delete", "repo fork", "repo rename",
  "release create", "release delete",
]);

// Tools that are safe for read-only dispatch in plan mode.
const SAFE_DISPATCH_TOOLS = new Set(["read", "grep", "find", "ls", "bash", "glob"]);

function isSafeBashCommand(cmd: string): boolean {
  const trimmed = cmd.trim();

  // bd commands always pass through
  if (/^bd\s/.test(trimmed) || trimmed === "bd") return true;

  // Pipelines / chains: check each segment
  const segments = trimmed.split(/\s*(?:\||&&|;)\s*/);
  for (const segment of segments) {
    const tokens = segment.trim().split(/\s+/);
    const base = tokens[0];
    if (!base) return false;

    if (!READ_ONLY_COMMANDS.has(base)) return false;

    // Extra guard for git: block mutating subcommands
    if (base === "git") {
      const sub = tokens.find((t, i) => i > 0 && !t.startsWith("-"));
      if (sub && MUTATING_GIT.has(sub)) return false;
    }

    // Extra guard for gh: block mutating subcommand paths
    if (base === "gh" && tokens.length >= 3) {
      const ghPath = `${tokens[1]} ${tokens[2]}`;
      if (MUTATING_GH.has(ghPath)) return false;
    }

    // Block sed in-place edits
    if (base === "sed" && tokens.some(t => t === "-i" || t.startsWith("-i") || t === "--in-place")) {
      return false;
    }

    // Block find -exec/-delete
    if (base === "find" && tokens.some(t => ["-exec", "-execdir", "-delete", "-ok"].includes(t))) {
      return false;
    }

    // Block output redirection (crude but effective)
    if (segment.includes(">")) return false;
  }

  return true;
}

/**
 * Check if a dispatch payload only requests read-only tools.
 * Returns undefined (allow) or a block result.
 */
function validateDispatchPayload(input: any): { block: true; reason: string } | undefined {
  const tasks: any[] = input?.tasks ?? [];

  for (const task of tasks) {
    if (task.allowTreeMutation) {
      return { block: true, reason: "Plan mode — dispatch with tree mutation blocked." };
    }
    if (task.worktree) {
      return { block: true, reason: "Plan mode — dispatch with worktree blocked." };
    }
    const tools: string[] = task.tools ?? [];
    if (tools.length === 0) {
      // Default tool set includes write/edit — must be explicit
      return { block: true, reason: "Plan mode — dispatch must specify a read-only tool allowlist." };
    }
    for (const t of tools) {
      if (!SAFE_DISPATCH_TOOLS.has(t)) {
        return { block: true, reason: `Plan mode — dispatch requests unsafe tool '${t}'.` };
      }
    }
  }

  return undefined; // all tasks are read-only, allow
}

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event: ToolCallEvent) => {
    if (!isPlanModeActive()) return;

    if (event.toolName === "write" || event.toolName === "edit") {
      const targetPath: string =
        (event.input as any).path ?? (event.input as any).filePath ?? "";
      if (targetPath.endsWith(".md")) {
        return {
          ask: true,
          reason: `Plan mode — confirm markdown file write: ${targetPath}`,
        };
      }
      return {
        block: true,
        reason:
          "Plan mode active — file modifications blocked. Switch to orchestrator to make changes.",
      };
    }

    if (event.toolName === "bash") {
      const cmd: string = (event.input as any).command ?? "";
      if (isSafeBashCommand(cmd)) return; // read-only commands pass through
      return {
        ask: true,
        reason:
          `Plan mode — command not in read-only allowlist. Allow?: ${cmd.slice(0, 120)}`,
      };
    }

    if (event.toolName === "dispatch") {
      return validateDispatchPayload(event.input);
    }

    if (event.toolName === "workflow" || event.toolName === "mcpScript") {
      return {
        block: true,
        reason: `Plan mode active — ${event.toolName} is blocked. Switch to orchestrator to dispatch work.`,
      };
    }
  });
}
