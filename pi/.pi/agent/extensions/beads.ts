// beads — Pi extension
// Automatic bd prime context injection on session start and after compaction.
// Reuses bd codex-hook subcommands for consistent behavior across agents.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";
import { statSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI): void {
  let primeCache = "";
  let hasBeads = false;

  async function runPrime(cwd: string): Promise<void> {
    try {
      const result = await pi.exec("bd", ["codex-hook", "SessionStart"], {
        cwd,
        timeout: 15000,
      });
      if (result.stdout) primeCache = result.stdout.trim();
    } catch {
      // bd not available or no beads workspace
    }
  }

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    try {
      statSync(join(ctx.cwd, ".beads"));
      hasBeads = true;
      await runPrime(ctx.cwd);
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
    async (event: SessionBeforeCompactEvent, _ctx) => {
      if (!hasBeads || !primeCache) return;
      // Inject beads context into the compaction summary so it survives compaction.
      const baseSummary = event.preparation?.previousSummary ?? "";
      return {
        compaction: {
          summary: baseSummary
            ? `${baseSummary}\n\n## Beads Context (preserved)\n${primeCache}`
            : `## Beads Context (preserved)\n${primeCache}`,
          firstKeptEntryId: event.preparation.firstKeptEntryId,
          tokensBefore: event.preparation.tokensBefore,
        },
      };
    },
  );

  pi.on("session_compact", async (_event: SessionCompactEvent, ctx) => {
    if (!hasBeads) return;
    await runPrime(ctx.cwd);
  });
}
