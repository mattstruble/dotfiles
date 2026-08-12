// plan-mode-guard — Pi extension
// Enforces read-only mode when the planner profile is active.
// Reads plan-mode state from globalThis.__piPlanMode (set by agent-profiles extension).
// Allowed in plan mode: read, grep, glob, fetch (read-only by nature), and bd commands.
// Blocked in plan mode: write, edit, and all bash except `bd *`.

import type { ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

function isPlanModeActive(): boolean {
  return (globalThis as any).__piPlanMode === true;
}

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event: ToolCallEvent) => {
    if (!isPlanModeActive()) return;

    if (event.toolName === "write" || event.toolName === "edit") {
      return {
        block: true,
        reason:
          "Plan mode active — file modifications blocked. Switch to orchestrator to make changes.",
      };
    }

    if (event.toolName === "bash") {
      const cmd: string = (event.input as any).command ?? "";
      if (/^\s*bd\s/.test(cmd)) return; // bd commands pass through
      return {
        block: true,
        reason:
          "Plan mode active — only bd commands allowed in bash. Switch to orchestrator for full access.",
      };
    }
  });
}
