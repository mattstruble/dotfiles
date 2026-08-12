// agent-profiles — Pi extension
// Cycles between planner and orchestrator profiles via Tab shortcut.
// Each profile carries a model + system prompt injection.
// Plan-mode extension reads `currentPlanMode` export to decide whether to activate.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

interface Profile {
  name: string;
  model: string;
  instructions: string;
  planMode: boolean;
}

const PLANNER_INSTRUCTIONS = `\
# Planner Agent

You decompose work into beads tasks. Your workflow:
1. Q&A loop to understand the spec — ask clarifying questions before creating tasks
2. Create epics and tasks with \`bd create\` (include acceptance criteria, design decisions)
3. Add dependencies with \`bd dep add\`
4. Spawn plan-critic for stress-testing, or self-critique the task graph
5. Present the refined plan to the user for approval — stop there, do not execute

You are READ-ONLY. Do not modify files. Only use bd commands and read tools.
Never start implementing. Your job ends when the user approves the plan.`;

const ORCHESTRATOR_INSTRUCTIONS = `\
# Orchestrator Agent

You execute from the beads task graph. Your workflow:
1. \`bd ready\` — find unblocked tasks
2. Decide grouping and parallelism
3. Invoke /workflow beads-dispatch with task IDs to spawn coder agents
4. Track completion, handle failures, re-spawn as needed
5. When all tasks are done, validate cumulative output against acceptance criteria

You have full tool access. You coordinate — you do not implement directly.
If no task graph exists, direct the user to switch to the planner profile first.`;

const profiles: Profile[] = [
  {
    name: "planner",
    model: process.env.PI_PLANNER_MODEL ?? "bedrock/us.anthropic.claude-opus-4-6-v1",
    instructions: PLANNER_INSTRUCTIONS,
    planMode: true,
  },
  {
    name: "orchestrator",
    model: process.env.PI_ORCHESTRATOR_MODEL ?? "bedrock/us.anthropic.claude-opus-4-6-v1",
    instructions: ORCHESTRATOR_INSTRUCTIONS,
    planMode: false,
  },
];

// Exported so plan-mode extension can read it without a custom event bus.
export let currentPlanMode: boolean = false;

export default function (pi: ExtensionAPI): void {
  let currentIndex = -1; // -1 = no profile active (default agent behaviour)

  function currentProfile(): Profile | null {
    return currentIndex >= 0 ? profiles[currentIndex] : null;
  }

  function cycleProfile(ctx: ExtensionCommandContext): void {
    currentIndex = (currentIndex + 1) % profiles.length;
    const profile = profiles[currentIndex];
    currentPlanMode = profile.planMode;

    pi.setModel(profile.model);
    ctx.ui.setStatus("profile", `[${profile.name}]`);
    ctx.ui.notify(`Profile: ${profile.name} (${profile.model})`, "info");
  }

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    const profile = currentProfile();
    if (profile) {
      ctx.ui.setStatus("profile", `[${profile.name}]`);
    }
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      const profile = currentProfile();
      if (!profile) return;
      const base = event.systemPrompt ? `${event.systemPrompt}\n\n` : "";
      return { systemPrompt: `${base}${profile.instructions}` };
    },
  );

  pi.registerShortcut("tab", {
    description: "Cycle agent profile (planner → orchestrator → …)",
    handler: async (_ctx: ExtensionCommandContext) => {
      cycleProfile(_ctx);
    },
  });

  pi.registerCommand("profile", {
    description: "Show or set agent profile: status | planner | orchestrator",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const arg = args.trim().toLowerCase();

      if (!arg || arg === "status") {
        const profile = currentProfile();
        ctx.ui.notify(profile ? `Profile: ${profile.name}` : "Profile: none (default)", "info");
        return;
      }

      const idx = profiles.findIndex((p) => p.name === arg);
      if (idx === -1) {
        ctx.ui.notify(
          `Unknown profile '${arg}'. Available: ${profiles.map((p) => p.name).join(", ")}`,
          "warning",
        );
        return;
      }

      currentIndex = idx;
      const profile = profiles[currentIndex];
      currentPlanMode = profile.planMode;
      pi.setModel(profile.model);
      ctx.ui.setStatus("profile", `[${profile.name}]`);
      ctx.ui.notify(`Profile: ${profile.name} (${profile.model})`, "info");
    },
  });
}
