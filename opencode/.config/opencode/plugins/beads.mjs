// beads — OpenCode plugin
// Automatic bd prime context injection on session start and after compaction.
// Reuses bd codex-hook subcommands for consistent behavior across agents.

import { execSync } from "child_process";
import fs from "fs";
import path from "path";

function hasBeads(directory) {
  try {
    return fs.statSync(path.join(directory, ".beads")).isDirectory();
  } catch {
    return false;
  }
}

function runHook(hook, cwd) {
  try {
    return execSync(`bd codex-hook ${hook}`, {
      cwd,
      encoding: "utf8",
      timeout: 10000,
    }).trim();
  } catch {
    return "";
  }
}

export const BeadsPlugin = async ({ directory }) => {
  let primeCache = "";
  let needsRefresh = false;

  if (hasBeads(directory)) {
    primeCache = runHook("SessionStart", directory);
  }

  return {
    "experimental.chat.system.transform": async (_input, output) => {
      if (!hasBeads(directory)) return;

      if (needsRefresh) {
        primeCache = runHook("UserPromptSubmit", directory);
        needsRefresh = false;
      }

      if (primeCache) {
        output.system.push(primeCache);
      }
    },

    "experimental.session.compacting": async (_input, output) => {
      if (!hasBeads(directory)) return;
      const ctx = runHook("PreCompact", directory);
      if (ctx) output.context.push(ctx);
    },

    event: async ({ event }) => {
      if (event.type === "session.compacted" && hasBeads(directory)) {
        runHook("PostCompact", directory);
        primeCache = runHook("SessionStart", directory);
        needsRefresh = false;
      }
    },
  };
};
