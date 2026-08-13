// statusline — single-line footer consolidating all status info
// Replaces @narumitw/pi-statusline with a simple, theme-aware one-liner.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { visibleWidth, truncateToWidth } from "@earendil-works/pi-tui";
import { basename } from "node:path";

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.setFooter((tui, theme, footerData) => {
      let requestRender: (() => void) | undefined = () => tui.requestRender();
      const branchUnsub = footerData.onBranchChange(() => requestRender?.());

      // Re-render periodically for time/context updates
      const timer = setInterval(() => requestRender?.(), 30_000);

      return {
        dispose() {
          branchUnsub();
          clearInterval(timer);
          requestRender = undefined;
        },
        invalidate() {},
        render(width: number): string[] {
          const segments: string[] = [];

          // Agent mode (from agent-profiles extension)
          const statuses = footerData.getExtensionStatuses();
          const profileStatus = statuses.get("profile");
          if (profileStatus) {
            const name = profileStatus.replace(/\x1b\[[0-9;]*m/g, "").replace(/[\[\]]/g, "").trim();
            const modeColors: Record<string, string> = {
              planner: "mdLink",
              orchestrator: "customMessageLabel",
              builder: "accent",
            };
            const color = modeColors[name] ?? "muted";
            segments.push(theme.fg(color as any, name));
          }

          // Model + thinking level (collapsed: model:effort)
          const model = ctx.model;
          if (model) {
            const id = (model as any).modelId ?? (model as any).id ?? String(model);
            const short = id
              .replace(/^anthropic\//, "")
              .replace(/^openai\//, "")
              .replace(/-\d{8}$/, "");
            const thinking = ctx.thinkingLevel;
            if (thinking && thinking !== "off") {
              const thinkingColors: Record<string, string> = {
                minimal: "thinkingMinimal",
                low: "thinkingLow",
                medium: "thinkingMedium",
                high: "thinkingHigh",
                xhigh: "thinkingXhigh",
                max: "thinkingMax",
              };
              const tColor = thinkingColors[thinking] ?? "muted";
              segments.push(theme.fg("accent", short) + theme.fg("dim", ":") + theme.fg(tColor as any, thinking));
            } else {
              segments.push(theme.fg("accent", short));
            }
          }

          // Directory + branch
          const dir = basename(ctx.cwd);
          const branch = footerData.getGitBranch();
          if (branch) {
            segments.push(theme.fg("text", `${dir}`) + theme.fg("muted", `:${branch}`));
          } else {
            segments.push(theme.fg("text", dir));
          }

          // Context usage
          const usage = ctx.getContextUsage?.();
          if (usage) {
            const toK = (n: number) => n >= 1000 ? `${Math.round(n / 1000)}k` : String(n);
            const used = usage.percent != null
              ? toK(Math.round(usage.contextWindow * usage.percent / 100))
              : "?";
            const window = toK(usage.contextWindow);
            const color = (usage.percent ?? 0) >= 90 ? "error"
              : (usage.percent ?? 0) >= 70 ? "warning"
              : "muted";
            segments.push(theme.fg(color as any, `ctx ${used}/${window}`));
          }

          // Extension statuses (mcp, cache, etc.) — inline them
          for (const [key, value] of statuses) {
            if (!value?.trim()) continue;
            // Skip our own key, profile (rendered above), and legacy key
            if (key === "statusline" || key === "pi-statusline" || key === "profile" || key === "ponytail") continue;
            const clean = value.replace(/\x1b\[[0-9;]*m/g, "").trim();
            if (clean) {
              segments.push(theme.fg("dim", clean));
            }
          }

          // Time
          const now = new Date();
          const time = `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`;
          segments.push(theme.fg("muted", time));

          const line = segments.join(theme.fg("dim", "  ·  "));

          // Truncate if wider than terminal
          if (visibleWidth(line) > width) {
            // Just render what fits — segments are priority-ordered
            let built = "";
            let builtLen = 0;
            for (let i = 0; i < segments.length; i++) {
              const sep = i > 0 ? theme.fg("dim", "  ·  ") : "";
              const sepLen = i > 0 ? 5 : 0;
              const segWidth = visibleWidth(segments[i]);
              if (builtLen + sepLen + segWidth > width) break;
              built += sep + segments[i];
              builtLen += sepLen + segWidth;
            }
            return [truncateToWidth(built, width)];
          }

          return [line];
        },
      };
    });
  });
}
