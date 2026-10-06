// beads — Pi extension
// Automatic bd prime context injection on session start and after compaction.
// One database per repo on the shared Dolt server, discovered from .beads/.
// BEADS_DIR is unset for every call (it would override discovery). Repos are
// initialized lazily on the first bd write.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";
import { basename, dirname } from "node:path";
import { existsSync } from "node:fs";
import { bdVerbs } from "./guardrails.ts";

/** bd database prefix for a repo directory. */
export function derivePrefix(dir: string): string {
  return basename(dir).toLowerCase().replace(/[^a-z0-9-]/g, "-");
}

/** True when the command runs a bd verb that writes (create, q, remember, import). */
export function isBdWrite(command: string): boolean {
  return bdVerbs(command).some((v) => ["create", "q", "remember", "import"].includes(v));
}


// ── Prime output filtering ────────────────────────────────────────────────

/**
 * Extract only dynamic content from bd prime output.
 * Static behavioral rules live in SYSTEM.md; only memories are injected.
 * Returns empty string when there are no memories.
 */
function slimPrime(raw: string): string {
  // Parse the JSON envelope (codex-hook wraps in JSON)
  let content = raw;
  try {
    const parsed = JSON.parse(raw);
    content = parsed?.hookSpecificOutput?.additionalContext ?? raw;
  } catch {
    // Not JSON — use raw content directly
  }

  // Extract the Persistent Memories section
  const memStart = content.indexOf("## Persistent Memories");
  if (memStart === -1) return "";

  // Find the end: next h1 or h2 that isn't a h3 memory entry
  const afterHeader = content.indexOf("\n", memStart);
  const rest = content.slice(afterHeader);
  const endMatch = rest.match(/\n#{1,2}\s+(?!#)/);
  const memories = endMatch
    ? rest.slice(0, endMatch.index).trim()
    : rest.trim();

  if (!memories) return "";
  return `## Persistent Memories\n${memories}`;
}

// ── Extension ─────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI): void {
  let primeCache = "";
  let hasBeads = false;

  // pi.exec has no env option; unset BEADS_DIR via env(1).
  function runBd(args: string[], cwd: string, timeout: number) {
    return pi.exec("env", ["-u", "BEADS_DIR", "bd", ...args], { cwd, timeout });
  }

  async function runPrime(cwd: string): Promise<void> {
    try {
      const result = await runBd(["codex-hook", "SessionStart"], cwd, 15000);
      if (result.stdout) primeCache = slimPrime(result.stdout.trim());
    } catch {
      // bd not available or shared server not running
    }
  }

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    try {
      await runPrime(ctx.cwd);
      hasBeads = primeCache.length > 0;
    } catch {
      hasBeads = false;
    }
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      if (!hasBeads || !primeCache) return;
      return { systemPrompt: event.systemPrompt + "\n\n" + primeCache };
    },
  );

  pi.on(
    "session_before_compact",
    async (event: SessionBeforeCompactEvent, ctx) => {
      if (!hasBeads) return;
      let compactCtx = primeCache;
      try {
        const result = await runBd(["codex-hook", "PreCompact"], ctx.cwd, 10000);
        if (result.stdout?.trim()) compactCtx = slimPrime(result.stdout.trim());
      } catch {
        // Fall back to cached primeCache
      }
      if (!compactCtx) return;
      const baseSummary = event.preparation?.previousSummary ?? "";
      return {
        compaction: {
          summary: baseSummary
            ? `${baseSummary}\n\n## Beads Context (preserved)\n${compactCtx}`
            : `## Beads Context (preserved)\n${compactCtx}`,
          firstKeptEntryId: event.preparation.firstKeptEntryId,
          tokensBefore: event.preparation.tokensBefore,
        },
      };
    },
  );

  pi.on("session_compact", async (_event: SessionCompactEvent, ctx) => {
    if (!hasBeads) return;
    try {
      await runBd(["codex-hook", "PostCompact"], ctx.cwd, 10000);
    } catch {
      // non-fatal
    }
    await runPrime(ctx.cwd);
  });

  // ponytail: init targets the session cwd's repo, not a `cd` target inside the command.
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    try {
      const command = String((event.input as { command?: unknown }).command ?? "");
      if (!isBdWrite(command)) return;
      const git = await pi.exec(
        "git",
        ["rev-parse", "--path-format=absolute", "--git-common-dir"],
        { cwd: ctx.cwd, timeout: 5000 },
      );
      const common = git.stdout?.trim();
      if (git.code !== 0 || !common) return;
      const main = dirname(common);
      if (existsSync(`${main}/.beads`)) return;
      const init = await runBd(
        ["init", "--shared-server", "--external", "--stealth", "--non-interactive", "--init-if-missing", "-p", derivePrefix(main)],
        main,
        30000,
      );
      if (init.code === 0) {
        await runPrime(ctx.cwd);
        hasBeads = primeCache.length > 0;
      }
    } catch {
      // never block the tool call
    }
  });
}
