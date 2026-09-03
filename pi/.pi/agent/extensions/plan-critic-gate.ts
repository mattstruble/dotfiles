import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * plan-critic-gate extension
 *
 * Registers the /critique command for manual plan-critic dispatch.
 * When triggered, injects a directive on the next agent turn forcing dispatch
 * of the plan-critic agent with read-only tools.
 */
export default function (pi: ExtensionAPI): void {
  let pendingCritique = false;

  // Inject critique directive before next agent start
  pi.on("before_agent_start", async (event) => {
    if (!pendingCritique) return;
    pendingCritique = false;

    const directive = [
      "## PLAN CRITIC DIRECTIVE",
      "",
      "You MUST dispatch plan-critic on this turn. No exceptions.",
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
      "- Do NOT skip the dispatch. The critic MUST run as a separate agent.",
      "- Do NOT self-critique instead of dispatching.",
      "- The dispatch uses read-only tools only.",
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
