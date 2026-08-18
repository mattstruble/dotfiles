// agent-profiles — Pi extension
// Cycles between planner, orchestrator, and builder profiles via Tab shortcut.
// Each profile carries a model (resolved from model-map.json) and system prompt injection.
// Publishes `active_agent` session entries so pi-permission-system resolves
// per-agent frontmatter overrides.
// Intercepts dispatch tool calls to inject per-agent models from the map.
// Blocks write/edit/bash-mutation tools in orchestrator mode.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join } from "node:path";

interface Profile {
  name: string;
  instructions: string;
  blockMutation?: boolean;
}

interface ModelMap {
  default?: string;
  small_model?: string;
  [agentName: string]: string | undefined;
}

function loadModelMap(): ModelMap {
  try {
    const mapPath = join(process.env.HOME ?? "", ".pi/agent/model-map.json");
    return JSON.parse(readFileSync(mapPath, "utf8"));
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    if (!msg.includes("ENOENT")) {
      console.warn(`[agent-profiles] Failed to load model-map.json: ${msg}`);
    }
    return {};
  }
}

function resolveModel(modelMap: ModelMap, agentName: string): string {
  return modelMap[agentName] ?? modelMap.default ?? "amazon-bedrock/us.anthropic.claude-sonnet-4-6";
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
Tell the user to use \`/orchestrate <epic-id>\` (or switch to builder for simple tasks) to execute.`;

const ORCHESTRATOR_INSTRUCTIONS = `\
# Orchestrator Agent

You execute the beads task graph by dispatching subagents. You NEVER implement code directly.

## Autonomy

Execute the entire epic to completion in a single turn. Do not pause for confirmation between waves.
Continue dispatching until \`bd ready --parent <epic-id>\` returns empty or all remaining tasks are stuck.
Only stop for critical blockers: all tasks stuck, infrastructure failures, or ambiguous acceptance criteria requiring human judgment.
Do not ask what to do next. Do not wait for user input between batches.

## Available Tools
- \`dispatch\` — spawn coder and reviewer subagents (your primary tool)
- \`read\`, \`grep\`, \`find\`, \`ls\` — inspect files and task state
- \`bash\` — ONLY for \`bd\` commands (read task state, close tasks)

## Blocked Tools
- \`write\`, \`edit\` — BLOCKED. You cannot modify files. You coordinate, not implement.

## Workflow

1. Run \`bd ready --parent <epic-id>\` to find unblocked tasks
2. Dispatch up to 3 coder subagents in parallel using the \`dispatch\` tool:
   - Set \`worktree: true\` on each task (Pi manages lifecycle + cleanup)
   - Set \`agent: "coder"\` (model auto-injected from model-map)
   - Set \`allowTreeMutation: true\`
   - Include full task context from \`bd show <id>\` in the task prompt
3. When coders complete, dispatch all 4 reviewers for each completed task:
   - agents: correctness-reviewer, failure-path-reviewer, readability-reviewer, security-reviewer
   - tools: ["read", "bash", "grep", "find", "ls"]
   - Include the coder's output/diff in the review prompt
4. Review loop (per task):
   - If ALL 4 reviewers say LGTM → task passes, close it with \`bd close\`
   - If any reviewer has findings → re-dispatch the coder with findings (up to 2 retries)
   - On retry: only re-run the reviewers that had findings
   - After targeted retries pass: run all 4 reviewers one final time
   - If final validation has findings: 1 more coder retry, then mark stuck

   ## Findings Relay

   Reviewers do not write to beads. Their findings return to you via the dispatch result.
   On retry: relay ONLY the current-cycle non-LGTM reviewer output to the coder.
   Do not include findings from prior cycles — they are stale.
5. After each batch completes: run \`bd ready --parent <epic-id>\` again for newly unblocked tasks
6. Continue until no ready tasks remain

## Dispatch Format for Coders

\`\`\`
dispatch({tasks: [{
  task: "## Task Assignment\\n\\n**Task ID**: <id>\\n**Repo root**: <cwd>\\n\\n## Task Context\\n\\n<bd show output>\\n\\n## Instructions\\n\\nImplement this task. Claim it first with \`bd update <id> --claim\`. Create subtasks for progress tracking. Commit your changes when done.",
  agent: "coder",
  worktree: true,
  allowTreeMutation: true,
  tools: ["read", "write", "edit", "bash", "grep", "glob", "fetch"]
}]})
\`\`\`

## Dispatch Format for Reviewers

Always re-run \`bd show <id>\` before dispatching reviewers to get current acceptance criteria.

\`\`\`
dispatch({tasks: [{
  task: "## Review Request\\n\\n**Task**: <id>\\n**Focus**: correctness\\n\\n## Scope\\nEvaluate ONLY whether this diff satisfies the acceptance criteria below.\\nFindings about pre-existing issues, unrelated files, or broader repo concerns are OUT OF SCOPE.\\nOnly report findings that would block merging THIS specific change.\\n\\n## Acceptance Criteria\\n<paste from bd show>\\n\\n## Diff\\n\`\`\`diff\\n<diff>\\n\`\`\`\\n\\nRespond LGTM if code passes. Otherwise list findings.",
  agent: "correctness-reviewer",
  tools: ["read", "bash", "grep", "find", "ls"]
}]})
\`\`\`

## Rules
- NEVER use write or edit tools — they are blocked
- NEVER implement code yourself — always dispatch a coder
- Max 3 coders in parallel per batch
- Close tasks with \`bd close <id>\` after all reviewers LGTM
- If a task fails 3 review cycles: skip it, report to user at the end
- Report final summary: passed tasks, stuck tasks, and why`;

const BUILDER_INSTRUCTIONS = `\
# Builder Agent

You implement directly. No beads workflow, no task graphs, no code review loop.
Read the request, understand the codebase, make the change, verify it works.

Use the full tool set: read, write, edit, bash, grep, find, ls.
Run tests/checks after changes when applicable.

For complex multi-task work, suggest the user switch to planner then use \`/orchestrate\`.
For everything else, just build it.`;

const profiles: Profile[] = [
  {
    name: "planner",
    instructions: PLANNER_INSTRUCTIONS,
  },
  {
    name: "orchestrator",
    instructions: ORCHESTRATOR_INSTRUCTIONS,
    blockMutation: true,
  },
  {
    name: "builder",
    instructions: BUILDER_INSTRUCTIONS,
  },
];

export default function (pi: ExtensionAPI): void {
  let currentIndex = -1; // -1 = no profile active (default agent behaviour)
  let sessionCtx: any = null;
  let modelMap: ModelMap = loadModelMap();

  function currentProfile(): Profile | null {
    return currentIndex >= 0 ? profiles[currentIndex] : null;
  }

  function updateStatus(profile: Profile | null): void {
    const ctx = sessionCtx;
    if (!ctx) return;
    if (profile) {
      const model = resolveModel(modelMap, profile.name);
      ctx.ui.setStatus("profile", `[${profile.name}] ${model}`);
    } else {
      ctx.ui.setStatus("profile", undefined);
    }
  }

  function activateProfile(profile: Profile): void {
    const model = resolveModel(modelMap, profile.name);
    pi.appendEntry("active_agent", { name: profile.name });
    pi.setModel(model);
    updateStatus(profile);
  }

  function cycleProfile(ctx: ExtensionCommandContext): void {
    currentIndex = (currentIndex + 1) % profiles.length;
    const profile = profiles[currentIndex];
    activateProfile(profile);
    const model = resolveModel(modelMap, profile.name);
    ctx.ui.notify(`Profile: ${profile.name} (${model})`, "info");
  }

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    sessionCtx = ctx;
    modelMap = loadModelMap();
    if (currentIndex < 0) {
      currentIndex = 0; // planner
      activateProfile(profiles[currentIndex]);
    } else {
      updateStatus(currentProfile());
    }
  });

  // Block mutation tools in orchestrator mode + inject models on dispatch
  pi.on("tool_call", async (event) => {
    const profile = currentProfile();

    // Block write/edit in orchestrator mode
    if (profile?.blockMutation) {
      if (event.toolName === "write" || event.toolName === "edit") {
        throw new Error(
          `[orchestrator] ${event.toolName} is blocked. You coordinate via dispatch, not implement directly.`,
        );
      }
    }

    // Inject per-agent models from model-map into dispatch calls
    if (event.toolName === "dispatch" && event.input?.tasks) {
      for (const task of event.input.tasks) {
        if (task.agent && !task.model) {
          const mapped = modelMap[task.agent];
          if (mapped) task.model = mapped;
          else if (modelMap.default) task.model = modelMap.default;
        }
      }
    }
  });

  let pendingOrchestrate: string | null = null;

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      let base = event.systemPrompt ? `${event.systemPrompt}\n\n` : "";

      // Inject profile identity
      const profile = currentProfile();
      if (profile) {
        const agentTag = `<active_agent name="${profile.name}" />`;
        base = `${base}${agentTag}\n\n${profile.instructions}\n\n`;
      }

      // Inject orchestrate directive if pending
      if (pendingOrchestrate) {
        const epicId = pendingOrchestrate;
        pendingOrchestrate = null;
        const directive = [
          "## ORCHESTRATE NOW",
          "",
          `Epic: \`${epicId}\``,
          "",
          "Begin the orchestration loop immediately:",
          `1. Run \`bd ready --parent ${epicId}\` to find unblocked tasks`,
          "2. For each ready task, run `bd show <id>` to get context",
          "3. Dispatch up to 3 coders in parallel",
          "4. After coders complete, dispatch reviewers",
          "5. Handle the review loop as specified in your instructions",
          "",
          "Start now. Do not ask for confirmation.",
        ].join("\n");
        base = `${base}${directive}\n\n`;
      }

      if (base.trim()) return { systemPrompt: base.trimEnd() };
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
      const model = resolveModel(modelMap, profile.name);
      ctx.ui.notify(`Profile: ${profile.name} (${model})`, "info");
    },
  });

  pi.registerCommand("orchestrate", {
    description: "Switch to orchestrator and begin executing an epic: /orchestrate <epic-id>",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const epicId = args.trim();
      if (!epicId) {
        ctx.ui.notify("Usage: /orchestrate <epic-id>", "warning");
        return;
      }

      // Switch to orchestrator profile
      const orchIdx = profiles.findIndex((p) => p.name === "orchestrator");
      if (orchIdx >= 0) {
        currentIndex = orchIdx;
        activateProfile(profiles[currentIndex]);
      }

      pendingOrchestrate = epicId;
      ctx.ui.notify(`Orchestrating ${epicId} — dispatching on next turn.`, "info");
    },
  });
}
