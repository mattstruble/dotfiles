import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  let previousPlanMode: boolean | undefined = undefined;
  let planRationale: string[] = [];
  let handoffContext: string | null = null;
  let bridgeActive = false;
  let sessionCwd = "";

  function isPlanMode(): boolean {
    return !!(globalThis as any).__piPlanMode;
  }

  function detectTransition(): "activated" | "deactivated" | null {
    const current = isPlanMode();
    if (previousPlanMode === true && current === false) {
      previousPlanMode = current;
      return "deactivated";
    }
    if (previousPlanMode === false && current === true) {
      previousPlanMode = current;
      return "activated";
    }
    previousPlanMode = current;
    return null;
  }

  async function buildHandoffContext(): Promise<string> {
    const execOpts = { cwd: sessionCwd, timeout: 10000 };
    let readyOut = "";
    let openOut = "";
    try {
      const ready = await pi.exec("bd", ["ready"], execOpts);
      readyOut = ready.stdout?.trim() ?? "";
    } catch { /* non-fatal */ }
    try {
      const open = await pi.exec("bd", ["list", "--status=open"], execOpts);
      openOut = open.stdout?.trim() ?? "";
    } catch { /* non-fatal */ }

    const lines: string[] = ["## Plan Handoff", "The following tasks are ready for execution:", ""];

    if (readyOut) {
      lines.push("### Ready Tasks", "```", readyOut, "```", "");
    }

    if (openOut) {
      lines.push("### All Open Tasks", "```", openOut, "```", "");
    }

    if (planRationale.length > 0) {
      lines.push("### Planning Rationale", "");
      for (const entry of planRationale) {
        lines.push(entry, "");
      }
    }

    return lines.join("\n");
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionCwd = ctx.cwd;
    previousPlanMode = isPlanMode();
  });

  // Capture bd create outputs during plan mode for rationale caching
  pi.on("tool_call", async (event) => {
    if (!isPlanMode()) return;
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    if (/bd\s+create/.test(cmd)) {
      // Extract the title/description from the command for rationale
      const titleMatch = cmd.match(/--title[= ]"([^"]+)"/);
      const descMatch = cmd.match(/--description[= ]"([^"]+)"/);
      if (titleMatch) {
        const entry = descMatch
          ? `- ${titleMatch[1]}: ${descMatch[1]}`
          : `- ${titleMatch[1]}`;
        planRationale.push(entry);
      }
    }
  });

  // On before_agent_start, detect transition and inject context
  pi.on("before_agent_start", async (event, _ctx) => {
    const transition = detectTransition();

    if (transition === "deactivated") {
      handoffContext = await buildHandoffContext();
      bridgeActive = true;
      planRationale = [];
    }

    if (bridgeActive && handoffContext) {
      const base = event.systemPrompt ?? "";
      return { systemPrompt: `${base}\n\n${handoffContext}` };
    }
  });

  // Survive compaction by re-injecting handoff context
  pi.on("session_before_compact", async (event, _ctx) => {
    if (!bridgeActive || !handoffContext) return;
    const baseSummary = (event as any).preparation?.previousSummary ?? "";
    return {
      compaction: {
        summary: baseSummary
          ? `${baseSummary}\n\n${handoffContext}`
          : handoffContext,
        firstKeptEntryId: (event as any).preparation.firstKeptEntryId,
        tokensBefore: (event as any).preparation.tokensBefore,
      },
    };
  });

  // Clear bridge state on shutdown
  pi.on("session_shutdown", async () => {
    bridgeActive = false;
    handoffContext = null;
    planRationale = [];
    previousPlanMode = undefined;
  });

  // Manual /handoff command
  pi.registerCommand("handoff", {
    description: "Generate and display the plan-to-orchestrator handoff context",
    handler: async (_args, ctx) => {
      const context = await buildHandoffContext();
      handoffContext = context;
      bridgeActive = true;
      ctx.ui.notify(context, "info");
    },
  });
}
