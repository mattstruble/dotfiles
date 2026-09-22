// beads — Pi extension
// Automatic bd prime context injection on session start and after compaction.
// Uses --global to target the shared beads_global database. BEADS_DIR and
// BEADS_DOLT_SHARED_SERVER are set via nix-darwin session variables.
// No per-project init needed — shared server runs as a launchd agent.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";


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
// Shared-server mode: BEADS_DIR and BEADS_DOLT_SHARED_SERVER are set via
// nix-darwin session variables. All commands use --global to target the
// beads_global database. No per-project init needed.

export default function (pi: ExtensionAPI): void {
  let primeCache = "";
  let hasBeads = false;

  function bd(args: string[]) {
    return ["--global", ...args];
  }

  async function runPrime(cwd: string): Promise<void> {
    try {
      const result = await pi.exec("bd", bd(["codex-hook", "SessionStart"]), {
        cwd,
        timeout: 15000,
      });
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
        const result = await pi.exec("bd", bd(["codex-hook", "PreCompact"]), {
          cwd: ctx.cwd,
          timeout: 10000,
        });
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
      await pi.exec("bd", bd(["codex-hook", "PostCompact"]), {
        cwd: ctx.cwd,
        timeout: 10000,
      });
    } catch {
      // non-fatal
    }
    await runPrime(ctx.cwd);
  });
}
