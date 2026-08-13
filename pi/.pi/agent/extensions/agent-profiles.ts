// agent-profiles — Pi extension
// Cycles between planner, orchestrator, and builder profiles via Tab shortcut.
// Each profile carries a model, system prompt injection, and permission identity.
// Publishes `active_agent` session entries so pi-permission-system resolves
// per-agent frontmatter overrides.

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
2. Explore the codebase with read, grep, find, ls, and bash (read-only commands)
3. Create epics and tasks with \`bd create\` (include acceptance criteria, design decisions)
4. Add dependencies with \`bd dep add\`
5. Spawn plan-critic for stress-testing, or self-critique the task graph
6. Present the refined plan to the user for approval — stop there, do not execute

You are READ-ONLY. Do not modify files. Only use bd commands and read tools.
Never start implementing. Your job ends when the user approves the plan.
Tell the user to switch to the orchestrator (or builder for simple tasks) to execute.`;

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

const BUILDER_INSTRUCTIONS = `\
# Builder Agent

You implement directly. No beads workflow, no task graphs, no code review loop.
Read the request, understand the codebase, make the change, verify it works.

Use the full tool set: read, write, edit, bash, grep, find, ls.
Run tests/checks after changes when applicable.

For complex multi-task work, suggest the user switch to planner → orchestrator.
For everything else, just build it.`;

const profiles: Profile[] = [
  {
    name: "planner",
    model: process.env.PI_PLANNER_MODEL ?? process.env.PI_DEFAULT_MODEL ?? "us.anthropic.claude-opus-4-6-v1",
    instructions: PLANNER_INSTRUCTIONS,
    planMode: true,
  },
  {
    name: "orchestrator",
    model: process.env.PI_ORCHESTRATOR_MODEL ?? process.env.PI_DEFAULT_MODEL ?? "us.anthropic.claude-opus-4-6-v1",
    instructions: ORCHESTRATOR_INSTRUCTIONS,
    planMode: false,
  },
  {
    name: "builder",
    model: process.env.PI_BUILDER_MODEL ?? process.env.PI_DEFAULT_SMALL_MODEL ?? process.env.PI_DEFAULT_MODEL ?? "us.anthropic.claude-sonnet-4-6-v1",
    instructions: BUILDER_INSTRUCTIONS,
    planMode: false,
  },
];

// Exported so plan-mode extension can read it without a custom event bus.
export let currentPlanMode: boolean = false;

export default function (pi: ExtensionAPI): void {
  let currentIndex = -1; // -1 = no profile active (default agent behaviour)
  let sessionCtx: any = null;

  function currentProfile(): Profile | null {
    return currentIndex >= 0 ? profiles[currentIndex] : null;
  }

  function updateStatus(profile: Profile | null): void {
    const ctx = sessionCtx;
    if (!ctx) return;
    if (profile) {
      ctx.ui.setStatus("profile", `[${profile.name}]`);
    } else {
      ctx.ui.setStatus("profile", undefined);
    }
  }

  function activateProfile(profile: Profile): void {
    currentPlanMode = profile.planMode;
    (globalThis as any).__piPlanMode = profile.planMode;

    // Publish active_agent entry so pi-permission-system resolves per-agent overrides
    pi.appendEntry("active_agent", { name: profile.name });

    pi.setModel(profile.model);
    updateStatus(profile);
  }

  function cycleProfile(ctx: ExtensionCommandContext): void {
    currentIndex = (currentIndex + 1) % profiles.length;
    const profile = profiles[currentIndex];
    activateProfile(profile);
    ctx.ui.notify(`Profile: ${profile.name} (${profile.model})`, "info");
  }

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    sessionCtx = ctx;
    updateStatus(currentProfile());
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      const profile = currentProfile();
      if (!profile) return;
      const base = event.systemPrompt ? `${event.systemPrompt}\n\n` : "";
      // Include active_agent tag so permission system can resolve agent identity from prompt
      const agentTag = `<active_agent name="${profile.name}" />`;
      return { systemPrompt: `${base}${agentTag}\n\n${profile.instructions}` };
    },
  );

  pi.registerShortcut("tab", {
    description: "Cycle agent profile (planner → orchestrator → builder → …)",
    handler: async (_ctx: ExtensionCommandContext) => {
      cycleProfile(_ctx);
    },
  });

  pi.registerCommand("profile", {
    description: "Show or set agent profile: status | planner | orchestrator | builder",
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
      activateProfile(profile);
      ctx.ui.notify(`Profile: ${profile.name} (${profile.model})`, "info");
    },
  });
}
