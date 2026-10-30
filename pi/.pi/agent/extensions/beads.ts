// beads — Pi extension
// Automatic bd prime context injection on session start and after compaction.
// One database per repo on the shared Dolt server; bd_store owns where each
// repo's store lives. The bd wrapper creates a missing store on any call, so
// this extension only calls bd once a store exists (bd_store --lookup) and
// creates the store itself on the agent's first bd write. Repos that never get
// a ticket never get a database.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";
import { join } from "node:path";
import { bdVerbs } from "./guardrails.ts";

const BD_STORE = join(homedir(), ".local", "bin", "bd_store");

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
  let hasStore = false;

  /** True when the cwd's repo already has a store; never creates one. */
  async function storeExists(cwd: string): Promise<boolean> {
    const result = await pi.exec(BD_STORE, ["--lookup"], { cwd, timeout: 5000 });
    return result.code === 0 && Boolean(result.stdout?.trim());
  }

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
      hasStore = await storeExists(ctx.cwd);
      if (hasStore) await runPrime(ctx.cwd);
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

  // ponytail: the store is created for the session cwd's repo, not a `cd` target inside the command.
  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash" || hasStore) return;
    try {
      const command = String((event.input as { command?: unknown }).command ?? "");
      if (!isBdWrite(command)) return;
      const create = await pi.exec(BD_STORE, [], { cwd: ctx.cwd, timeout: 30000 });
      if (create.code !== 0) return;
      hasStore = true;
      await runPrime(ctx.cwd);
      hasBeads = primeCache.length > 0;
    } catch {
      // never block the tool call
    }
  });
}
