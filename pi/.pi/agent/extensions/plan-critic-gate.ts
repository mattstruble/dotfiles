import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * plan-critic-gate extension
 *
 * Registers the /critique command for manual plan-critic run via the subagent tool.
 * When triggered, injects a directive on the next agent turn forcing a subagent call
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
      "You MUST run plan-critic via the `subagent` tool on this turn. No exceptions.",
      "",
      "### Instructions",
      "",
      "1. Call the `subagent` tool with the plan-critic agent (read-only) to review the task graph:",
      "   ```",
      '   subagent({',
      '     agent: "plan-critic",',
      '     task: "Run plan-critic: evaluate the current beads task graph. Use `bd list --json`, `bd show <id> --json`, `bd dep tree`, and `bd dep cycles` to assess. Return structured findings per the plan-critic methodology (missing-dep, unclear-criteria, scope-gap, oversized, duplicate, ordering). Return \\"No further suggestions.\\" if the plan is sound."',
      "   })",
      "   ```",
      "",
      "2. Read the critic's response.",
      '   - If "No further suggestions." → the plan is ready. Present it to the user.',
      "   - If findings exist → apply them using `bd update`, `bd create`, `bd dep add` as needed.",
      "",
      "3. After applying fixes, re-run the plan-critic (same subagent call).",
      "",
      "4. Repeat until the critic returns 'No further suggestions.' OR you reach 3 rounds.",
      "   After 3 rounds, present the plan with any remaining suggestions noted.",
      "",
      "### Rules",
      "- Do NOT skip the subagent call. The critic MUST run as a separate agent.",
      "- Do NOT self-critique instead of calling subagent.",
      "- The plan-critic agent must stay read-only.",
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
