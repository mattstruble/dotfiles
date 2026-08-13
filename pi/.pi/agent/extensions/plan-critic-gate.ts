import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * plan-critic-gate extension
 *
 * Auto-triggers plan-critic dispatch after a planning session creates ≥2 beads tasks.
 * Injects a directive telling the planner to dispatch plan-critic with read-only tools
 * and iterate up to 3 rounds until the critic returns "No further suggestions."
 */
export default function (pi: ExtensionAPI): void {
  let createdThisTurn: string[] = [];
  let pendingCritique = false;

  // Track `bd create` commands in tool_call events
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    if (/bd\s+create/.test(cmd)) {
      createdThisTurn.push(cmd);
    }
  });

  // After agent settles, check if we should trigger critique
  pi.on("agent_settled", async () => {
    if (createdThisTurn.length >= 2) {
      const autoTrigger = (globalThis as any).__piPlanMode === true;
      if (autoTrigger) {
        pendingCritique = true;
      }
    }
    createdThisTurn = [];
  });

  // Inject critique directive before next agent start
  pi.on("before_agent_start", async (event) => {
    if (!pendingCritique) return;
    pendingCritique = false;

    const directive = [
      "## PLAN CRITIC DIRECTIVE",
      "",
      "A task graph was just created. You MUST now run the plan→critique→refine loop:",
      "",
      "### Instructions",
      "",
      "1. Dispatch a plan-critic agent with read-only tools to review the task graph:",
      "   ```",
      '   dispatch([{',
      '     task: "Run plan-critic: evaluate the current beads task graph. Use `bd list --json`, `bd show <id> --json`, `bd dep tree`, and `bd dep cycles` to assess. Return structured findings per the plan-critic methodology (missing-dep, unclear-criteria, scope-gap, oversized, duplicate, ordering). Return \\"No further suggestions.\\" if the plan is sound.",',
      '     agent: "plan-critic",',
      '     tools: ["read", "grep", "find", "ls", "bash"]',
      "   }])",
      "   ```",
      "",
      "2. Read the critic's response.",
      '   - If "No further suggestions." → the plan is ready. Present it to the user.',
      "   - If findings exist → apply them using `bd update`, `bd create`, `bd dep add` as needed.",
      "",
      "3. After applying fixes, re-dispatch the plan-critic (same dispatch call).",
      "",
      "4. Repeat until the critic returns 'No further suggestions.' OR you reach 3 rounds.",
      "   After 3 rounds, present the plan with any remaining suggestions noted.",
      "",
      "### Rules",
      "- Do NOT skip the dispatch. The critic must run as a separate agent.",
      "- Do NOT self-critique instead of dispatching.",
      "- The dispatch uses read-only tools only — this is allowed in plan mode.",
    ].join("\n");

    const base = event.systemPrompt ?? "";
    return { systemPrompt: `${base}\n\n${directive}` };
  });

  // Manual /critique command
  pi.registerCommand("critique", {
    description: "Manually trigger plan-critic review of the task graph",
    handler: async (_args, ctx) => {
      pendingCritique = true;
      ctx.ui.notify("Plan critique will run on next agent turn.", "info");
    },
  });
}
