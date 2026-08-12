import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  let cachedResult: { timestamp: number; report: string; issueCount: number } | null = null;
  let sessionCwd = "";
  let sessionCtx: any = null;
  const CACHE_TTL_MS = 60_000;

  function isCacheValid(): boolean {
    return cachedResult !== null && Date.now() - cachedResult.timestamp < CACHE_TTL_MS;
  }

  async function runChecks(): Promise<{ report: string; issueCount: number }> {
    const execOpts = { cwd: sessionCwd, timeout: 10000 };
    const lines: string[] = [];
    let issues = 0;

    // 1. Git status — dirty working tree check
    try {
      const git = await pi.exec("git", ["status", "--porcelain"], execOpts);
      if (git.stdout?.trim()) {
        const fileCount = git.stdout.trim().split("\n").length;
        lines.push(`⚠ Working tree is dirty (${fileCount} file${fileCount > 1 ? "s" : ""})`);
        issues++;
      } else {
        lines.push("✓ Working tree clean");
      }
    } catch (e: any) {
      lines.push(`✗ Git status failed: ${e.message ?? e}`);
      issues++;
    }

    // 2. bd doctor --check=conventions
    try {
      const doctor = await pi.exec("bd", ["doctor", "--check=conventions"], execOpts);
      if (doctor.stderr?.trim() || doctor.stdout?.includes("FAIL") || doctor.stdout?.includes("error")) {
        lines.push(`⚠ Convention issues: ${doctor.stdout?.trim() || doctor.stderr?.trim()}`);
        issues++;
      } else {
        lines.push("✓ Conventions pass");
      }
    } catch (e: any) {
      lines.push(`✗ bd doctor failed: ${e.message ?? e}`);
      issues++;
    }

    // 3. bd orphans — broken dependencies
    try {
      const orphans = await pi.exec("bd", ["orphans"], execOpts);
      if (orphans.stdout?.trim()) {
        const orphanCount = orphans.stdout.trim().split("\n").length;
        lines.push(`⚠ ${orphanCount} broken dependenc${orphanCount > 1 ? "ies" : "y"} found`);
        issues++;
      } else {
        lines.push("✓ No broken dependencies");
      }
    } catch (e: any) {
      lines.push(`✗ bd orphans failed: ${e.message ?? e}`);
      issues++;
    }

    // 4. bd ready — check tasks have description content
    try {
      const ready = await pi.exec("bd", ["ready"], execOpts);
      const readyOutput = ready.stdout?.trim() ?? "";
      if (!readyOutput) {
        lines.push("✓ No ready tasks (queue empty)");
      } else {
        const taskLines = readyOutput.split("\n").filter((l: string) => l.trim());
        const taskIds = taskLines
          .map((l: string) => {
            const parts = l.trim().split(/\s+/);
            return parts[1] ?? null;
          })
          .filter((id: string | null) => id && /^[a-z][a-z0-9]*-[a-z0-9]+/.test(id));

        const emptyTasks: string[] = [];
        const tasksWithPaths: string[] = [];

        // Check first few tasks for description content and file paths
        const checkLimit = Math.min(taskIds.length, 5);
        for (let i = 0; i < checkLimit; i++) {
          try {
            const show = await pi.exec("bd", ["show", taskIds[i]], execOpts);
            const content = show.stdout?.trim() ?? "";
            // Check for meaningful description (more than just a title line)
            const descLines = content.split("\n").slice(1).filter((l: string) => l.trim());
            if (descLines.length === 0) {
              emptyTasks.push(taskIds[i]);
            }
            // 5. Heuristic: check if description mentions file paths
            if (content.includes("/") || /\.(ts|py|nix|js|json|yaml|yml|toml|md)\b/.test(content)) {
              tasksWithPaths.push(taskIds[i]);
            }
          } catch {
            // Skip tasks we can't show
          }
        }

        if (emptyTasks.length > 0) {
          lines.push(`⚠ ${emptyTasks.length} ready task(s) lack description: ${emptyTasks.join(", ")}`);
          issues++;
        } else {
          lines.push(`✓ ${taskIds.length} ready task(s), all have descriptions`);
        }

        if (tasksWithPaths.length > 0) {
          lines.push(`✓ ${tasksWithPaths.length} task(s) reference file paths: ${tasksWithPaths.join(", ")}`);
        } else {
          lines.push(`⚠ No ready tasks reference specific file paths`);
          issues++;
        }
      }
    } catch (e: any) {
      lines.push(`✗ bd ready failed: ${e.message ?? e}`);
      issues++;
    }

    const header = issues === 0
      ? "── Preflight ✓ All clear ──"
      : `── Preflight ⚠ ${issues} issue${issues > 1 ? "s" : ""} ──`;

    const report = [header, ...lines].join("\n");
    return { report, issueCount: issues };
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionCwd = ctx.cwd;
    sessionCtx = ctx;
  });

  // Register /preflight command
  pi.registerCommand("preflight", {
    description: "Run pre-dispatch validation checks on the task graph and repo state",
    handler: async (_args, ctx) => {
      cachedResult = null; // Force fresh run on explicit command
      const result = await runChecks();
      cachedResult = { timestamp: Date.now(), ...result };
      ctx.ui.setStatus("preflight", result.issueCount === 0 ? "✓ clean" : `⚠ ${result.issueCount} issues`);
      ctx.ui.notify(result.report, result.issueCount === 0 ? "info" : "warning");
    },
  });

  // Auto-trigger on before_agent_start when dispatching
  pi.on("before_agent_start", async (event, _ctx) => {
    const prompt = (event.prompt ?? "").toLowerCase();
    const shouldTrigger =
      !(globalThis as any).__piPlanMode &&
      (prompt.includes("dispatch") || prompt.includes("workflow") || prompt.includes("execute"));

    if (!shouldTrigger) return;

    let report: string;
    if (isCacheValid()) {
      report = cachedResult!.report;
    } else {
      const result = await runChecks();
      cachedResult = { timestamp: Date.now(), ...result };
      // Update status if we have a session context
      if (sessionCtx?.hasUI) {
        try {
          sessionCtx.ui.setStatus(
            "preflight",
            result.issueCount === 0 ? "✓ clean" : `⚠ ${result.issueCount} issues`,
          );
        } catch {
          // best-effort
        }
      }
      report = result.report;
    }

    const base = event.systemPrompt ?? "";
    return { systemPrompt: `${base}\n\n${report}` };
  });

  pi.on("session_shutdown", async () => {
    cachedResult = null;
    sessionCtx = null;
  });
}
