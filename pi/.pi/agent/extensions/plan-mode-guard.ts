import type { ExtensionAPI, ToolCallEvent } from "@earendil-works/pi-coding-agent";

function isPlanModeActive(): boolean {
  return (globalThis as any).__piPlanMode === true;
}

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event: ToolCallEvent) => {
    if (!isPlanModeActive()) return;

    if (event.toolName === "write" || event.toolName === "edit") {
      const targetPath: string =
        (event.input as any).path ?? (event.input as any).filePath ?? "";
      if (targetPath.endsWith(".md")) {
        return {
          ask: true,
          reason: `Plan mode — confirm markdown file write: ${targetPath}`,
        };
      }
      return {
        block: true,
        reason:
          "Plan mode active — file modifications blocked. Switch to orchestrator to make changes.",
      };
    }

    if (event.toolName === "bash") {
      const cmd: string = (event.input as any).command ?? "";
      if (/^\s*bd\s/.test(cmd)) return; // bd commands pass through
      return {
        block: true,
        reason:
          "Plan mode active — only bd commands allowed in bash. Switch to orchestrator for full access.",
      };
    }

    if (
      event.toolName === "dispatch" ||
      event.toolName === "workflow" ||
      event.toolName === "mcpScript"
    ) {
      return {
        block: true,
        reason: `Plan mode active — ${event.toolName} is blocked. Switch to orchestrator to dispatch work.`,
      };
    }
  });
}
