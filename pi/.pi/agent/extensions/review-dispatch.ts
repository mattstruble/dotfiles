import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  const pendingReview: Map<string, string> = new Map(); // taskId -> title
  const reviewed: Set<string> = new Set();
  let sessionCtx: any = null;

  pi.on("session_start", async (_event, ctx) => {
    sessionCtx = ctx;
  });

  // Track bd close commands for coder/implement tasks
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    const match = cmd.match(/bd\s+close\s+(\S+)/);
    if (!match) return;

    const taskId = match[1];
    const fullCmd = cmd.toLowerCase();
    if (fullCmd.includes("coder") || fullCmd.includes("implement")) {
      if (!reviewed.has(taskId)) {
        pendingReview.set(taskId, taskId);
      }
    }
  });

  // After agent settles, update status if reviews are pending
  pi.on("agent_settled", async (_event, ctx) => {
    if (pendingReview.size > 0 && ctx.hasUI) {
      ctx.ui.setStatus("review", `⏳ ${pendingReview.size} task(s) awaiting review`);
    }
  });

  // Inject review directive before next agent start
  pi.on("before_agent_start", async (event, _ctx) => {
    if (pendingReview.size === 0) return;

    const taskLines = Array.from(pendingReview.entries())
      .map(([id, title]) => `- ${id}: ${title}`)
      .join("\n");

    const directive = [
      "## REVIEW DISPATCH DIRECTIVE",
      "",
      "The following tasks were just completed by coders and need review.",
      "Create review subtasks and dispatch reviewers:",
      taskLines,
      "",
      "For each, create correctness-review and failure-path-review subtasks under the parent,",
      "then dispatch reviewer subagents with the git diff.",
    ].join("\n");

    // Move to reviewed and clear pending
    for (const taskId of pendingReview.keys()) {
      reviewed.add(taskId);
    }
    pendingReview.clear();

    // Clear status
    if (sessionCtx?.hasUI) {
      try { sessionCtx.ui.setStatus("review", undefined); } catch { /* */ }
    }

    const base = event.systemPrompt ?? "";
    return { systemPrompt: `${base}\n\n${directive}` };
  });

  // Manual command: /review <task-id>
  pi.registerCommand("review", {
    description: "Manually queue a task for review dispatch",
    handler: async (args, ctx) => {
      const taskId = args.trim();
      if (!taskId) {
        ctx.ui.notify("Usage: /review <task-id>", "warning");
        return;
      }

      if (reviewed.has(taskId)) {
        ctx.ui.notify(`Task ${taskId} was already reviewed`, "info");
        return;
      }

      // Fetch task title via bd
      let title = taskId;
      try {
        const result = await pi.exec("bd", ["show", taskId], { timeout: 10000 });
        const titleMatch = result.stdout?.match(/title[:\s]+(.+)/i);
        if (titleMatch) title = titleMatch[1].trim();
      } catch {
        // fallback to taskId as title
      }

      pendingReview.set(taskId, title);
      ctx.ui.notify(`Task ${taskId} queued for review dispatch`, "info");
    },
  });

  // Status command: /reviews
  pi.registerCommand("reviews", {
    description: "Show pending and completed review status",
    handler: async (_args, ctx) => {
      const lines: string[] = [];

      if (pendingReview.size > 0) {
        lines.push("Pending review dispatch:");
        for (const [id, title] of pendingReview) {
          lines.push(`  ⏳ ${id}: ${title}`);
        }
      } else {
        lines.push("No tasks pending review.");
      }

      if (reviewed.size > 0) {
        lines.push("");
        lines.push(`Already reviewed: ${Array.from(reviewed).join(", ")}`);
      }

      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  pi.on("session_shutdown", async () => {
    sessionCtx = null;
  });
}
