import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * plan-critic-gate extension
 *
 * Auto-dispatches the plan-critic agent after a planning session creates ≥2 beads tasks.
 * When globalThis.__piPlanMode is true, triggers automatically.
 * Otherwise, use /critique to trigger manually.
 */
export default function (pi: ExtensionAPI): void {
  let createdThisTurn: string[] = [];
  let pendingCritique = false;
  let critiqueTaskIds: string[] = [];

  // Track `bd create` commands in tool_call events
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    if (/bd\s+create/.test(cmd)) {
      // Extract a rough task identifier from the command (best-effort)
      createdThisTurn.push(cmd);
    }
  });

  // After agent settles, check if we should trigger critique
  pi.on("agent_settled", async () => {
    const count = createdThisTurn.length;

    if (count >= 2) {
      const autoTrigger = (globalThis as any).__piPlanMode === true;

      if (autoTrigger) {
        pendingCritique = true;
        critiqueTaskIds = [...createdThisTurn];
      }
    }

    // Reset per-turn counter
    createdThisTurn = [];
  });

  // Inject critique directive before next agent start
  pi.on("before_agent_start", async (event, _ctx) => {
    if (!pendingCritique) return;

    pendingCritique = false;
    const taskList = critiqueTaskIds
      .map((cmd, i) => `  ${i + 1}. \`${cmd}\``)
      .join("\n");
    critiqueTaskIds = [];

    const directive = [
      "## PLAN CRITIC DIRECTIVE",
      "",
      "A plan was just created with the following tasks:",
      taskList,
      "",
      "Dispatch the plan-critic reviewer before proceeding.",
      "Run `bd show <id>` for each newly created task, then evaluate:",
      "- Are tasks well-scoped and independently completable?",
      "- Are there missing steps or implicit dependencies?",
      "- Is ordering correct?",
      "- Are acceptance criteria clear?",
      "",
      "Summarize findings and suggest edits if needed. Then continue with the user's intent.",
    ].join("\n");

    const base = event.systemPrompt ?? "";
    return { systemPrompt: `${base}\n\n${directive}` };
  });

  // Manual /critique command
  pi.registerCommand("critique", {
    description: "Manually trigger plan-critic review of recently created tasks",
    handler: async (_args, ctx) => {
      if (critiqueTaskIds.length === 0 && createdThisTurn.length === 0) {
        ctx.ui.notify(
          "No recently created tasks to critique. Create tasks with `bd create` first.",
          "warn"
        );
        return;
      }

      pendingCritique = true;
      if (critiqueTaskIds.length === 0) {
        critiqueTaskIds = [...createdThisTurn];
      }
      ctx.ui.notify("Plan critique will run on next agent turn.", "info");
    },
  });

  // Clear status after critique completes
  pi.on("agent_end", async (_event, ctx) => {
    if (!pendingCritique && ctx.hasUI) {
      try { ctx.ui.setStatus("plan-critic", undefined); } catch { /* */ }
    }
  });
}
