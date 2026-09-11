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

      // Action Fusion: log fused bash command as a separate audit entry
      if (event.toolName === "edit" || event.toolName === "write") {
        const fusedCmd = (event.input as any)?.then_run?.command;
        if (typeof fusedCmd === "string") {
          const fusedEntry = {
            ts: Date.now(),
            tool: "bash (fused via then_run)",
            args: { command: fusedCmd },
            session: event.sessionId,
            fusedFrom: event.toolName,
          };
          appendFileSync(LOG_PATH, JSON.stringify(fusedEntry) + "\n");
        }
      }
    } catch {
      // never throw, never crash
    }
  });
}
