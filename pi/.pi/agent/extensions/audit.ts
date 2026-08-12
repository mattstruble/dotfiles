// audit — Pi extension
// Append-only tool call logging to ~/.local/share/pi/audit.jsonl.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const LOG_PATH = join(process.env.HOME ?? "", ".local/share/pi/audit.jsonl");

export default function (pi: ExtensionAPI): void {
  mkdirSync(join(process.env.HOME ?? "", ".local/share/pi"), { recursive: true });

  pi.on("tool_call", async (event) => {
    try {
      const entry = {
        ts: Date.now(),
        tool: event.toolName,
        args: event.input,
        session: event.sessionId,
      };
      appendFileSync(LOG_PATH, JSON.stringify(entry) + "\n");
    } catch {
      // never throw, never crash
    }
  });
}
