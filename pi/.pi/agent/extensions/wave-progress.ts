import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { statSync } from "node:fs";
import { join } from "node:path";

export default function (pi: ExtensionAPI): void {
  let total = 0;
  let completed = 0;
  let succeeded = 0;
  let failed = 0;
  let active = false;
  let sessionCtx: any = null;

  function updateStatus() {
    if (!sessionCtx?.hasUI) return;
    try {
      if (!active || total === 0) {
        sessionCtx.ui.setStatus("wave", undefined);
        return;
      }
      sessionCtx.ui.setStatus("wave", `[${completed}/${total} ✓${succeeded} ✗${failed}]`);
    } catch { /* best-effort */ }
  }

  function reset() {
    total = 0;
    completed = 0;
    succeeded = 0;
    failed = 0;
    active = false;
  }

  function hasBeads(cwd: string): boolean {
    try {
      statSync(join(cwd, ".beads"));
      return true;
    } catch {
      return false;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionCtx = ctx;
    reset();

    if (!hasBeads(ctx.cwd)) return;
    try {
      const result = await pi.exec("bd", ["stats"], { cwd: ctx.cwd, timeout: 10000 });
      const stdout = result.stdout ?? "";
      const totalMatch = stdout.match(/total[:\s]+(\d+)/i);
      const closedMatch = stdout.match(/closed[:\s]+(\d+)/i);

      if (totalMatch) total = parseInt(totalMatch[1], 10);
      if (closedMatch) completed = parseInt(closedMatch[1], 10);
      if (total > completed) active = true;
    } catch { /* bd stats unavailable */ }

    updateStatus();
  });

  // Track tool calls for dispatch and bd commands
  pi.on("tool_call", async (event) => {
    const toolName = event.toolName;

    // Track dispatched tasks (workflow/dispatch tool calls)
    if (toolName === "dispatch" || toolName === "workflow") {
      active = true;
      total++;
      updateStatus();
      return;
    }

    if (toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";

    // Track bd close commands (optimistic success)
    if (/\bbd\s+close\b/.test(cmd)) {
      completed++;
      succeeded++;
      updateStatus();
    }
    // Track bd create (new task added)
    else if (/\bbd\s+create\b/.test(cmd)) {
      active = true;
      total++;
      updateStatus();
    }
  });

  // Detect failed closes from tool_result
  pi.on("tool_result", async (event) => {
    // If a bd close failed, undo the optimistic count
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    if (!/\bbd\s+close\b/.test(cmd)) return;

    const exitCode = (event as any).exitCode ?? (event as any).result?.exitCode;
    if (exitCode && exitCode !== 0) {
      succeeded--;
      failed++;
      updateStatus();
    }
  });

  pi.on("agent_settled", async () => {
    // If all tasks completed, clear active state
    if (active && total > 0 && completed >= total) {
      active = false;
      updateStatus();
    }
  });

  pi.on("session_shutdown", async () => {
    if (sessionCtx?.hasUI) {
      try { sessionCtx.ui.setStatus("wave", undefined); } catch { /* */ }
    }
    sessionCtx = null;
    reset();
  });

  pi.registerCommand("wave", {
    description: "Show current orchestration wave progress",
    handler: async (_args, ctx) => {
      if (!active && total === 0) {
        ctx.ui.notify("No orchestration active.", "info");
        return;
      }
      const pending = total - completed;
      ctx.ui.notify(
        `Wave Progress: ${completed}/${total} tasks done | ✓${succeeded} ✗${failed} | ${pending} pending`,
        "info",
      );
    },
  });
}
