// notification — Pi extension
// Terminal title reflecting session state with pi branding.
// States: ⏳ (working), 󰂞 (permission needed), ✓ (idle/done)
// Integrates with @nicknisi/pi-session-name for session titles and
// @gotgenes/pi-permission-system for permission prompt awareness.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { basename } from "node:path";

type State = "active" | "permission" | "idle";

export default function (pi: ExtensionAPI): void {
  let state: State = "idle";
  let sessionName: string | undefined;
  let cwd = "";
  let hasPermissions = false;

  function buildTitle(): string {
    const icon = state === "permission" ? "󰂞" : state === "active" ? "󰔟" : "󰄬";
    const label = sessionName || basename(cwd) || "π";
    return `${icon} π — ${label}`;
  }

  function updateTitle(ctx: { hasUI: boolean; ui: { setTitle(t: string): void } }): void {
    if (!ctx.hasUI) return;
    try {
      ctx.ui.setTitle(buildTitle());
    } catch {
      // best-effort
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    cwd = ctx.cwd;
    state = "idle";
    sessionName = pi.getSessionName?.() ?? undefined;
    updateTitle(ctx);

    // Set directory:branch status segment
    let branch = "";
    try {
      const result = await pi.exec("git", ["branch", "--show-current"], { cwd: ctx.cwd, timeout: 3000 });
      branch = result.stdout?.trim() ?? "";
    } catch {}
    const cwdLabel = branch ? `${basename(cwd)}:${branch}` : basename(cwd);
    ctx.ui.setStatus("cwd", cwdLabel);

    // Subscribe to permission UI prompts if the permission system is available
    try {
      pi.events?.on("permissions:ui_prompt", () => {
        state = "permission";
        updateTitle(ctx);
      });
      pi.events?.on("permissions:decision", () => {
        if (state === "permission") {
          state = "active";
          updateTitle(ctx);
        }
      });
      hasPermissions = true;
    } catch {
      // permission-system not installed — no permission state tracking
    }
  });

  pi.on("session_info_changed", async (event, ctx) => {
    sessionName = event.name ?? undefined;
    updateTitle(ctx);
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (state !== "permission") {
      state = "active";
      updateTitle(ctx);
    }
  });

  pi.on("agent_settled", async (_event, ctx) => {
    if (state !== "permission") {
      state = "idle";
      updateTitle(ctx);
    }
    // Refresh directory:branch status (branch may have changed)
    let branch = "";
    try {
      const result = await pi.exec("git", ["branch", "--show-current"], { cwd: ctx.cwd, timeout: 3000 });
      branch = result.stdout?.trim() ?? "";
    } catch {}
    const cwdLabel = branch ? `${basename(cwd)}:${branch}` : basename(cwd);
    ctx.ui.setStatus("cwd", cwdLabel);
  });

  pi.on("agent_end", async (_event, ctx) => {
    if (state !== "permission") {
      state = "idle";
      updateTitle(ctx);
    }
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    state = "idle";
    if (ctx.hasUI) {
      try {
        ctx.ui.setTitle("π");
      } catch {
        // best-effort
      }
    }
  });
}
