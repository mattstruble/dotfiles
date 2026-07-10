// knowledge-base — OpenCode plugin
// Guarantees ~/llm-wiki/INDEX.md is always in context, ensuring the LLM
// knows what cross-session knowledge is available without relying on
// AGENTS.md instruction compliance. Commits wiki changes on session idle.

import { execSync } from "child_process";
import fs from "fs";
import path from "path";

const WIKI_PATH = path.join(process.env.HOME, "llm-wiki");
const INDEX_PATH = path.join(WIKI_PATH, "INDEX.md");

function readIndex() {
  try {
    return fs.readFileSync(INDEX_PATH, "utf8").trim();
  } catch {
    return "";
  }
}

function commitIfDirty() {
  try {
    const status = execSync("git status --porcelain", {
      cwd: WIKI_PATH,
      encoding: "utf8",
      timeout: 5000,
    }).trim();
    if (status) {
      execSync(
        "git add -A && git commit -m 'auto-sync: session idle $(date -u +%Y-%m-%dT%H:%M:%SZ)' && git push",
        { cwd: WIKI_PATH, encoding: "utf8", timeout: 10000 },
      );
    }
  } catch {}
}

export const KnowledgeBasePlugin = async () => {
  let indexCache = readIndex();

  return {
    "experimental.chat.system.transform": async (_input, output) => {
      if (indexCache) {
        output.system.push(
          `## Knowledge Base (~/llm-wiki)\n\n` +
            `The following INDEX lists available cross-session knowledge. ` +
            `Use Read to traverse relevant notes when context would help.\n\n` +
            indexCache,
        );
      }
    },

    "experimental.session.compacting": async (_input, output) => {
      if (indexCache) {
        output.context.push(
          `Knowledge base INDEX (~/llm-wiki/INDEX.md) — ` +
            `preserve awareness of available notes:\n\n${indexCache}`,
        );
      }
    },

    event: async ({ event }) => {
      if (event.type === "session.compacted") {
        indexCache = readIndex();
      }
      if (event.type === "session.idle") {
        commitIfDirty();
      }
    },
  };
};
