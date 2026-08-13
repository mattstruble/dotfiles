import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  const pendingReview: Map<string, string> = new Map(); // taskId -> title
  const reviewed: Set<string> = new Set();

  // Track bd close commands — inspect any task closure
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";
    const match = cmd.match(/bd\s+close\s+(\S+)/);
    if (!match) return;

    const taskId = match[1];
    if (reviewed.has(taskId)) return;

    // Check task metadata to skip review tasks (prevents infinite loops)
    try {
      const result = await pi.exec("bd", ["show", taskId, "--json"], { timeout: 10000 });
      const json = JSON.parse(result.stdout ?? "[]");
      const task = Array.isArray(json) ? json[0] : json;
      const title: string = task?.title ?? "";

      // Skip if this is itself a review task
      if (/review/i.test(title)) return;

      pendingReview.set(taskId, title || taskId);
    } catch {
      // If we can't read metadata, queue it anyway — false positive is better than missed review
      pendingReview.set(taskId, taskId);
    }
  });

  // After agent settles, update status if reviews are pending
  pi.on("agent_settled", async (_event, ctx) => {
    if (pendingReview.size > 0 && ctx.hasUI) {
      ctx.ui.setStatus("review", `⏳ ${pendingReview.size} task(s) awaiting review`);
    }
  });

  // Inject review directive before next agent start
  pi.on("before_agent_start", async (event) => {
    if (pendingReview.size === 0) return;

    const taskLines = Array.from(pendingReview.entries())
      .map(([id, title]) => `- ${id}: ${title}`)
      .join("\n");

    const directive = [
      "## REVIEW DISPATCH DIRECTIVE",
      "",
      "The following tasks were just completed and need review.",
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
        const result = await pi.exec("bd", ["show", taskId, "--json"], { timeout: 10000 });
        const json = JSON.parse(result.stdout ?? "[]");
        const task = Array.isArray(json) ? json[0] : json;
        if (task?.title) title = task.title;
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
}
