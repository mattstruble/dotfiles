/**
 * model-routing.ts — fill in the model for `dispatch` tasks from ~/.pi/agent/model-map.json.
 *
 * pi-subagents only reads `model:` from profile frontmatter, and the profiles are
 * shared across hosts with different providers, so the per-host model-map
 * (programs.ai-agents.pi.modelMap) is the routing table: a task gets
 * map[profile], or map.default when the profile is unset or unmapped. An explicit task.model wins.
 * Entries may carry a thinking suffix (`provider/id:high`); pi-shared resolves it.
 *
 * Run: npx tsx --test pi/.pi/agent/extensions/model-routing.test.ts
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type ModelMap = Record<string, string>;
type Task = { profile?: string; model?: string };

export function routeTasks(tasks: Task[], map: ModelMap): void {
  for (const task of tasks) {
    if (task.model) continue;
    const model = (task.profile && map[task.profile]) || map.default;
    if (model) task.model = model;
  }
}

export default function (pi: ExtensionAPI): void {
  // Same default as pi's getAgentDir(); a value import of it would break the standalone test.
  const agentDir = process.env.PI_CODING_AGENT_DIR ?? path.join(os.homedir(), ".pi", "agent");
  const mapPath = path.join(agentDir, "model-map.json");

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "dispatch") return;
    const tasks = (event.input as { tasks?: Task[] }).tasks;
    if (!Array.isArray(tasks)) return;

    // Re-read per dispatch so a home-manager switch takes effect without restarting pi.
    let map: ModelMap;
    try {
      map = JSON.parse(fs.readFileSync(mapPath, "utf8"));
    } catch (err: any) {
      if (err?.code !== "ENOENT") ctx.ui.notify(`model-routing: cannot read ${mapPath}: ${err}`, "warning");
      return;
    }
    routeTasks(tasks, map);
  });
}
