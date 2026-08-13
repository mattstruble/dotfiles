// statusline — single-line footer consolidating all status info
// Replaces @narumitw/pi-statusline with a simple, theme-aware one-liner.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
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

          // Model
          const model = ctx.model;
          if (model) {
            const id = (model as any).modelId ?? (model as any).id ?? String(model);
            // Shorten common prefixes
            const short = id
              .replace(/^anthropic\//, "")
              .replace(/^openai\//, "")
              .replace(/-\d{8}$/, "");
            segments.push(theme.fg("accent", short));
          }

          // Thinking level
          const thinking = ctx.thinkingLevel;
          if (thinking && thinking !== "off") {
            segments.push(theme.fg("muted", `🧠 ${thinking}`));
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
            const pct = usage.percent != null ? `${usage.percent.toFixed(1)}%` : "?";
            const window = usage.contextWindow >= 1000
              ? `${Math.round(usage.contextWindow / 1000)}k`
              : String(usage.contextWindow);
            const color = (usage.percent ?? 0) >= 90 ? "error"
              : (usage.percent ?? 0) >= 70 ? "warning"
              : "muted";
            segments.push(theme.fg(color as any, `ctx ${pct}/${window}`));
          }

          // Extension statuses (mcp, cache, etc.) — inline them
          const statuses = footerData.getExtensionStatuses();
          for (const [key, value] of statuses) {
            if (!value?.trim()) continue;
            // Skip our own key and the narumitw key if somehow still present
            if (key === "statusline" || key === "pi-statusline") continue;
            // Strip ANSI from value for clean re-theming
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

          // Truncate if wider than terminal (strip ANSI for measurement)
          const plain = line.replace(/\x1b\[[0-9;]*m/g, "");
          if (plain.length > width) {
            // Just render what fits — segments are priority-ordered
            let built = "";
            let builtLen = 0;
            for (let i = 0; i < segments.length; i++) {
              const sep = i > 0 ? theme.fg("dim", "  ·  ") : "";
              const sepLen = i > 0 ? 5 : 0;
              const segPlain = segments[i].replace(/\x1b\[[0-9;]*m/g, "");
              if (builtLen + sepLen + segPlain.length > width) break;
              built += sep + segments[i];
              builtLen += sepLen + segPlain.length;
            }
            return [built];
          }

          return [line];
        },
      };
    });
  });
}
