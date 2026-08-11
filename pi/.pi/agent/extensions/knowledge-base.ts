// knowledge-base — Pi extension
// Guarantees ~/llm-wiki/INDEX.md is always in context, ensuring the LLM
// knows what cross-session knowledge is available. Commits wiki changes on agent_settled.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionBeforeCompactEvent,
  SessionCompactEvent,
  AgentSettledEvent,
} from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const WIKI_PATH = join(process.env.HOME ?? "", "llm-wiki");
const INDEX_PATH = join(WIKI_PATH, "INDEX.md");

function readIndex(): string {
  try {
    return readFileSync(INDEX_PATH, "utf8").trim();
  } catch {
    return "";
  }
}

export default function (pi: ExtensionAPI): void {
  let indexCache = readIndex();

  pi.on("session_start", async (_event: SessionStartEvent, _ctx) => {
    indexCache = readIndex();
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      if (!indexCache) return;
      const injection =
        `## Knowledge Base (~/llm-wiki)\n\n` +
        `The following INDEX lists available cross-session knowledge. ` +
        `Use Read to traverse relevant notes when context would help.\n\n` +
        indexCache;
      return { systemPrompt: event.systemPrompt + "\n\n" + injection };
    },
  );

  pi.on(
    "session_before_compact",
    async (event: SessionBeforeCompactEvent, _ctx) => {
      if (!indexCache) return;
      const wikiSection =
        `Knowledge base INDEX (~/llm-wiki/INDEX.md) — ` +
        `preserve awareness of available notes:\n\n${indexCache}`;
      const baseSummary = event.preparation?.previousSummary ?? "";
      return {
        compaction: {
          summary: baseSummary
            ? `${baseSummary}\n\n${wikiSection}`
            : wikiSection,
          firstKeptEntryId: event.preparation.firstKeptEntryId,
          tokensBefore: event.preparation.tokensBefore,
        },
      };
    },
  );

  pi.on("session_compact", async (_event: SessionCompactEvent, _ctx) => {
    indexCache = readIndex();
  });

  pi.on("agent_settled", async (_event: AgentSettledEvent, ctx) => {
    try {
      const status = await pi.exec("git", ["status", "--porcelain"], {
        cwd: WIKI_PATH,
        timeout: 5000,
      });
      if (!status.stdout?.trim()) return;
      const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
      await pi.exec(
        "sh",
        ["-c", `git add -A && git commit -m 'auto-sync: session idle ${timestamp}' && git push`],
        { cwd: WIKI_PATH, timeout: 15000 },
      );
    } catch {
      // wiki not a git repo or push failed — non-fatal
    }
  });
}
