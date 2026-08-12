// beads — Pi extension
// Automatic bd prime context injection on session start and after compaction.
// Reuses bd codex-hook subcommands for consistent behavior across agents.
// Filters the prime output to inject only dynamic/essential content, stripping
// the static command reference that the model can access via `bd --help`.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
} from "@earendil-works/pi-coding-agent";
import { statSync } from "node:fs";
import { join } from "node:path";

// ── Prime output filtering ────────────────────────────────────────────────

// Sections to KEEP (dynamic, per-session content)
const KEEP_SECTIONS = [
  "Persistent Memories",
  "SESSION CLOSE PROTOCOL",
  "Core Rules",
];

// Sections to STRIP (static command reference — model can use `bd --help`)
const STRIP_SECTIONS = [
  "Essential Commands",
  "Common Workflows",
  "Finding Work",
  "Creating & Updating",
  "Dependencies & Blocking",
  "Sync & Collaboration",
  "Project Health",
  "Quality Tools",
  "Lifecycle & Hygiene",
  "Structured Workflows",
];

/**
 * Filter bd prime output to keep only dynamic content.
 * Preserves: memories, core rules, session close protocol, context recovery note.
 * Strips: full command reference, common workflows, quality tools.
 * Appends a slim reference hint so the model knows commands exist.
 */
function slimPrime(raw: string): string {
  // Parse the JSON envelope if present (codex-hook wraps in JSON)
  let content = raw;
  try {
    const parsed = JSON.parse(raw);
    content = parsed?.hookSpecificOutput?.additionalContext ?? raw;
  } catch {
    // Not JSON — use raw content directly
  }

  const lines = content.split("\n");
  const kept: string[] = [];
  let inStrippedSection = false;
  let currentHeadingLevel = 0;
  let inCodeFence = false;

  for (const line of lines) {
    // Track code fences to avoid treating # comments as headings
    if (line.trimStart().startsWith("```")) {
      inCodeFence = !inCodeFence;
      if (!inStrippedSection) kept.push(line);
      continue;
    }

    // Only parse headings outside code fences
    const headingMatch = !inCodeFence ? line.match(/^(#{1,4})\s+(.+)/) : null;

    if (headingMatch) {
      const level = headingMatch[1].length;
      const title = headingMatch[2].trim();

      // Check if this heading starts a stripped section
      const shouldStrip = STRIP_SECTIONS.some(
        (s) => title.includes(s) || title.replace(/[^a-zA-Z ]/g, "").includes(s)
      );

      if (shouldStrip) {
        inStrippedSection = true;
        currentHeadingLevel = level;
        continue;
      }

      // If we hit a heading at the same or higher level, stop stripping
      if (inStrippedSection && level <= currentHeadingLevel) {
        inStrippedSection = false;
      }
    }

    if (!inStrippedSection) {
      kept.push(line);
    }
  }

  // Clean up excessive blank lines
  let result = kept.join("\n").replace(/\n{3,}/g, "\n\n").trim();

  // Append a slim hint so the model knows bd commands exist without the full reference
  result += `\n\n## Quick Reference\nUse \`bd --help\` or \`bd <command> --help\` for full command syntax.\nKey commands: \`bd ready\`, \`bd show <id>\`, \`bd create\`, \`bd close\`, \`bd update --claim\`, \`bd dep add\`.`;

  return result;
}

// ── Extension ─────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI): void {
  let primeCache = "";
  let hasBeads = false;

  async function runPrime(cwd: string): Promise<void> {
    try {
      const result = await pi.exec("bd", ["codex-hook", "SessionStart"], {
        cwd,
        timeout: 15000,
      });
      if (result.stdout) primeCache = slimPrime(result.stdout.trim());
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
    async (event: SessionBeforeCompactEvent, ctx) => {
      if (!hasBeads) return;
      // Call PreCompact hook for fresh context (mirrors opencode behavior)
      let compactCtx = primeCache;
      try {
        const result = await pi.exec("bd", ["codex-hook", "PreCompact"], {
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
    // Call PostCompact then refresh (mirrors opencode behavior)
    try {
      await pi.exec("bd", ["codex-hook", "PostCompact"], {
        cwd: ctx.cwd,
        timeout: 10000,
      });
    } catch {
      // non-fatal
    }
    await runPrime(ctx.cwd);
  });
}
