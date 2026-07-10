// audit — OpenCode plugin
// Append-only tool call logging to ~/.local/share/opencode/audit.jsonl.

import fs from "fs";
import path from "path";
import os from "os";

export const AuditPlugin = async () => {
  const logPath = path.join(os.homedir(), ".local/share/opencode/audit.jsonl");
  fs.mkdirSync(path.dirname(logPath), { recursive: true });

  return {
    "tool.execute.after": async (input) => {
      try {
        const entry = {
          ts: Date.now(),
          tool: input.tool,
          args: input.args,
          session: input.sessionID,
        };
        fs.appendFileSync(logPath, JSON.stringify(entry) + "\n");
      } catch {
        // never throw, never crash
      }
    },
  };
};
