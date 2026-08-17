// skills-picker — Pi extension
// Provides /skills command to toggle skill profiles and individual skills
// on/off mid-session with auto-reload. Scans ~/.pi/agent/skill-profiles/
// for available profiles and their contained skills.

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { readdirSync, statSync, mkdirSync, symlinkSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const SKILL_PROFILES_DIR = join(process.env.HOME ?? "", ".pi/agent/skill-profiles");
const TMP_BASE = join(tmpdir(), `pi-skills-${process.pid}`);

// State persists across extension re-initialization (reload) via globalThis
const STATE_KEY = Symbol.for("pi-skills-picker-state");
interface PersistedState {
  added: Set<string>;
  removed: Set<string>;
  disabledSkills: Map<string, Set<string>>; // profile -> disabled skill names
}
const state: PersistedState = (globalThis as any)[STATE_KEY] ??= {
  added: new Set<string>(),
  removed: new Set<string>(),
  disabledSkills: new Map<string, Set<string>>(),
};

// Cleanup temp dirs on process exit
function cleanupTmpDirs(): void {
  try {
    if (existsSync(TMP_BASE)) rmSync(TMP_BASE, { recursive: true, force: true });
  } catch { /* best effort */ }
}
process.on("exit", cleanupTmpDirs);
process.on("SIGTERM", () => { cleanupTmpDirs(); process.exit(0); });

export default function (pi: ExtensionAPI): void {
  function getBaselinePaths(): string[] {
    return (process.env.PI_SKILL_PATHS ?? "")
      .split(":")
      .filter((p) => p.length > 0);
  }

  function discoverProfiles(): Map<string, string> {
    const profiles = new Map<string, string>();
    try {
      for (const entry of readdirSync(SKILL_PROFILES_DIR)) {
        const fullPath = join(SKILL_PROFILES_DIR, entry);
        try {
          if (statSync(fullPath).isDirectory()) profiles.set(entry, fullPath);
        } catch { /* skip broken symlinks */ }
      }
    } catch { /* directory doesn't exist */ }
    return profiles;
  }

  function getSkillsInProfile(profilePath: string): string[] {
    try {
      return readdirSync(profilePath).filter((entry) => {
        try {
          const skillDir = join(profilePath, entry);
          return statSync(skillDir).isDirectory() &&
            existsSync(join(skillDir, "SKILL.md"));
        } catch { return false; }
      }).sort();
    } catch { return []; }
  }

  function getBaselineProfileNames(): Set<string> {
    const baseline = new Set<string>();
    for (const p of getBaselinePaths()) {
      const match = p.match(/skill-profiles\/([^/]+)\/?$/);
      if (match) baseline.add(match[1]);
    }
    return baseline;
  }

  function isProfileActive(name: string): boolean {
    const baseline = getBaselineProfileNames();
    return (baseline.has(name) && !state.removed.has(name)) || state.added.has(name);
  }

  /** Build the effective skill path for a profile, filtering out disabled skills */
  function buildProfilePath(profileName: string, realPath: string): string {
    const disabled = state.disabledSkills.get(profileName);
    if (!disabled || disabled.size === 0) return realPath;

    // Create synthetic dir with symlinks to enabled skills only
    const syntheticDir = join(TMP_BASE, profileName);
    rmSync(syntheticDir, { recursive: true, force: true });
    mkdirSync(syntheticDir, { recursive: true });

    for (const skill of getSkillsInProfile(realPath)) {
      if (!disabled.has(skill)) {
        symlinkSync(join(realPath, skill), join(syntheticDir, skill));
      }
    }
    return syntheticDir;
  }

  function getActivePaths(): string[] {
    const available = discoverProfiles();
    const paths: string[] = [];
    for (const [name, realPath] of available) {
      if (isProfileActive(name)) {
        paths.push(buildProfilePath(name, realPath));
      }
    }
    return paths;
  }

  // Provide skill paths on discovery (fires on startup and /reload)
  pi.on("resources_discover", async () => {
    const paths = getActivePaths();
    if (paths.length === 0) return;
    return { skillPaths: paths };
  });

  pi.registerCommand("skills", {
    description: "Toggle skill profiles: status | enable <name> | disable <name> | reset",
    getArgumentCompletions: (prefix: string) => {
      const normalized = prefix.trimStart();
      const argMatch = normalized.match(/^(\S+)\s+(.*)$/);

      if (!argMatch) {
        const subcommands = [
          { value: "enable", label: "enable — Activate a profile or skill" },
          { value: "disable", label: "disable — Deactivate a profile or skill" },
          { value: "status", label: "status — Show profile states" },
          { value: "reset", label: "reset — Revert to direnv baseline" },
        ].filter(({ value }) => value.startsWith(normalized));
        return subcommands.length > 0 ? subcommands : null;
      }

      const [, subcommand, argPrefix] = argMatch;
      if (subcommand !== "enable" && subcommand !== "disable") return null;

      const available = discoverProfiles();
      // Support profile/skill syntax for completion
      const completions: Array<{ value: string; label: string }> = [];
      const prefix2 = argPrefix.trimStart();

      if (prefix2.includes("/")) {
        // Completing a skill within a profile
        const [profName, skillPrefix] = prefix2.split("/", 2);
        const profPath = available.get(profName ?? "");
        if (profPath) {
          for (const skill of getSkillsInProfile(profPath)) {
            if (skill.startsWith(skillPrefix ?? "")) {
              completions.push({
                value: `${subcommand} ${profName}/${skill}`,
                label: `${profName}/${skill}`,
              });
            }
          }
        }
      } else {
        for (const name of available.keys()) {
          if (name.startsWith(prefix2)) {
            completions.push({ value: `${subcommand} ${name}`, label: name });
          }
        }
      }
      return completions.length > 0 ? completions : null;
    },
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const parts = args.trim().split(/\s+/);
      const subcommand = parts[0]?.toLowerCase() ?? "";
      const target = parts[1] ?? "";

      if (!subcommand) {
        showPanel(ctx);
        return;
      }

      if (subcommand === "status") {
        showStatus(ctx);
        return;
      }

      if (subcommand === "reset") {
        state.added.clear();
        state.removed.clear();
        state.disabledSkills.clear();
        ctx.ui.notify("Skill profiles reset to direnv baseline. Reloading…", "info");
        await triggerReload(ctx);
        return;
      }

      if (subcommand === "enable" || subcommand === "disable") {
        if (!target) {
          ctx.ui.notify(`Usage: /skills ${subcommand} <profile> or /skills ${subcommand} <profile>/<skill>`, "warning");
          return;
        }

        const available = discoverProfiles();

        if (target.includes("/")) {
          // Individual skill toggle
          const [profName, skillName] = target.split("/", 2);
          if (!profName || !skillName || !available.has(profName)) {
            ctx.ui.notify(`Unknown profile/skill: ${target}`, "warning");
            return;
          }
          const skills = getSkillsInProfile(available.get(profName)!);
          if (!skills.includes(skillName)) {
            ctx.ui.notify(`Unknown skill '${skillName}' in profile '${profName}'`, "warning");
            return;
          }

          let disabled = state.disabledSkills.get(profName);
          if (subcommand === "disable") {
            if (!disabled) { disabled = new Set(); state.disabledSkills.set(profName, disabled); }
            disabled.add(skillName);
          } else {
            // If profile is inactive, enable it with only this skill
            if (!isProfileActive(profName)) {
              const baseline = getBaselineProfileNames();
              state.removed.delete(profName);
              if (!baseline.has(profName)) state.added.add(profName);
              const allSkills = getSkillsInProfile(available.get(profName)!);
              const newDisabled = new Set(allSkills.filter((s) => s !== skillName));
              state.disabledSkills.set(profName, newDisabled);
            } else {
              disabled?.delete(skillName);
              if (disabled?.size === 0) state.disabledSkills.delete(profName);
            }
          }
          ctx.ui.notify(`${subcommand === "enable" ? "Enabled" : "Disabled"} skill: ${target}. Reloading…`, "info");
          await triggerReload(ctx);
          return;
        }

        // Profile-level toggle
        if (!available.has(target)) {
          ctx.ui.notify(
            `Unknown profile '${target}'. Available: ${[...available.keys()].join(", ")}`,
            "warning",
          );
          return;
        }

        if (subcommand === "enable") {
          state.removed.delete(target);
          if (!getBaselineProfileNames().has(target)) state.added.add(target);
        } else {
          state.added.delete(target);
          if (getBaselineProfileNames().has(target)) state.removed.add(target);
        }
        ctx.ui.notify(`${subcommand === "enable" ? "Enabled" : "Disabled"} profile: ${target}. Reloading…`, "info");
        await triggerReload(ctx);
        return;
      }

      ctx.ui.notify(
        `Unknown subcommand '${subcommand}'. Use: enable, disable, status, reset`,
        "warning",
      );
    },
  });

  function showStatus(ctx: ExtensionCommandContext): void {
    const available = discoverProfiles();
    const lines: string[] = [];
    let activeCount = 0;

    for (const [name, path] of [...available.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
      const active = isProfileActive(name);
      if (active) activeCount++;
      const skills = getSkillsInProfile(path);
      const disabled = state.disabledSkills.get(name);
      const enabledCount = active ? skills.length - (disabled?.size ?? 0) : 0;
      const baseline = getBaselineProfileNames();
      const suffix = active && baseline.has(name) ? " (baseline)" : active ? " (session)" : "";
      const icon = active ? "✓" : "⊘";
      lines.push(`${icon} ${name} ${enabledCount}/${skills.length}${suffix}`);
    }

    lines.unshift(`Skill Profiles (${activeCount} active, ${available.size} available):`, "");
    ctx.ui.notify(lines.join("\n"), "info");
  }

  interface PanelItem {
    type: "profile" | "skill";
    profileName: string;
    skillName?: string;
    active: boolean;
    isBaseline: boolean;
  }

  function showPanel(ctx: ExtensionCommandContext): void {
    const available = discoverProfiles();
    const expanded = new Set<string>();
    let cursorIndex = 0;
    let dirty = false;

    function buildItems(): PanelItem[] {
      const items: PanelItem[] = [];
      for (const [name, path] of [...available.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
        const active = isProfileActive(name);
        const baseline = getBaselineProfileNames();
        items.push({
          type: "profile",
          profileName: name,
          active,
          isBaseline: baseline.has(name),
        });

        if (expanded.has(name)) {
          const skills = getSkillsInProfile(path);
          const disabled = state.disabledSkills.get(name);
          for (const skill of skills) {
            items.push({
              type: "skill",
              profileName: name,
              skillName: skill,
              active: active && !(disabled?.has(skill) ?? false),
              isBaseline: baseline.has(name),
            });
          }
        }
      }
      return items;
    }

    ctx.ui.custom(
      (tui, _theme, _keybindings, done) => {
        let items = buildItems();

        const panel = {
          handleInput(data: string): void {
            if (matchesKey(data, "escape") || data === "q") {
              done(undefined);
              if (dirty) void triggerReload(ctx);
              return;
            }

            // Navigation
            if (matchesKey(data, "up") || data === "k") {
              cursorIndex = Math.max(0, cursorIndex - 1);
              tui.requestRender();
              return;
            }
            if (matchesKey(data, "down") || data === "j") {
              cursorIndex = Math.min(items.length - 1, cursorIndex + 1);
              tui.requestRender();
              return;
            }

            // Enter: expand/collapse profiles
            if (matchesKey(data, "enter")) {
              const item = items[cursorIndex];
              if (!item) return;
              if (item.type === "profile") {
                if (expanded.has(item.profileName)) {
                  expanded.delete(item.profileName);
                } else {
                  expanded.add(item.profileName);
                }
                items = buildItems();
                // Clamp cursor
                cursorIndex = Math.min(cursorIndex, items.length - 1);
                tui.requestRender();
              }
              return;
            }

            // Space: toggle
            if (matchesKey(data, "space")) {
              const item = items[cursorIndex];
              if (!item) return;

              if (item.type === "profile") {
                // Toggle profile
                if (item.active) {
                  state.added.delete(item.profileName);
                  if (item.isBaseline) state.removed.add(item.profileName);
                  item.active = false;
                } else {
                  state.removed.delete(item.profileName);
                  if (!item.isBaseline) state.added.add(item.profileName);
                  item.active = true;
                }
              } else if (item.skillName) {
                // Toggle individual skill
                if (item.active) {
                  let disabled = state.disabledSkills.get(item.profileName);
                  if (!disabled) { disabled = new Set(); state.disabledSkills.set(item.profileName, disabled); }
                  disabled.add(item.skillName);
                  item.active = false;
                } else {
                  // If profile is inactive, enable it with all skills disabled except this one
                  if (!isProfileActive(item.profileName)) {
                    const baseline = getBaselineProfileNames();
                    state.removed.delete(item.profileName);
                    if (!baseline.has(item.profileName)) state.added.add(item.profileName);
                    // Disable all skills except the one being enabled
                    const allSkills = getSkillsInProfile(available.get(item.profileName) ?? "");
                    const disabled = new Set(allSkills.filter((s) => s !== item.skillName));
                    state.disabledSkills.set(item.profileName, disabled);
                  } else {
                    const disabled = state.disabledSkills.get(item.profileName);
                    disabled?.delete(item.skillName);
                    if (disabled?.size === 0) state.disabledSkills.delete(item.profileName);
                  }
                  item.active = true;
                }
              }

              dirty = true;
              items = buildItems();
              tui.requestRender();
              return;
            }
          },

          render(width: number): string[] {
            const innerW = width - 2;
            const lines: string[] = [];
            const fg = (code: string, text: string) =>
              code ? `\x1b[${code}m${text}\x1b[0m` : text;
            const bold = (s: string) => `\x1b[1m${s}\x1b[22m`;
            const dim = (s: string) => `\x1b[2m${s}\x1b[22m`;

            const border = "2";
            const activeColor = "32";
            const inactiveColor = "2";
            const cursorColor = "36";
            const baselineColor = "33";
            const countColor = "2";

            const row = (content: string) =>
              fg(border, "│") +
              truncateToWidth(" " + content, innerW, "…", true) +
              fg(border, "│");
            const emptyRow = () =>
              fg(border, "│") + " ".repeat(innerW) + fg(border, "│");

            // Title
            const titleText = " Skill Profiles ";
            const borderLen = innerW - visibleWidth(titleText);
            const leftB = Math.floor(borderLen / 2);
            const rightB = borderLen - leftB;
            lines.push(
              fg(border, "╭" + "─".repeat(leftB)) +
              fg("1", titleText) +
              fg(border, "─".repeat(rightB) + "╮"),
            );
            lines.push(emptyRow());

            // Scrollable list
            const maxVis = 16;
            const total = items.length;
            const startIdx = Math.max(0, Math.min(cursorIndex - Math.floor(maxVis / 2), total - maxVis));
            const endIdx = Math.min(startIdx + maxVis, total);

            for (let i = startIdx; i < endIdx; i++) {
              const item = items[i];
              if (!item) continue;
              const isCursor = i === cursorIndex;

              if (item.type === "profile") {
                const path = available.get(item.profileName) ?? "";
                const skills = getSkillsInProfile(path);
                const disabled = state.disabledSkills.get(item.profileName);
                const enabledCount = item.active ? skills.length - (disabled?.size ?? 0) : 0;
                const arrow = expanded.has(item.profileName) ? "▾" : "▸";
                const icon = item.active ? fg(activeColor, "✓") : fg(inactiveColor, "⊘");
                const count = fg(countColor, `${enabledCount}/${skills.length}`);
                const suffix = item.active && item.isBaseline
                  ? dim(" (baseline)")
                  : item.active
                    ? fg(baselineColor, " (session)")
                    : "";
                const name = isCursor
                  ? fg(cursorColor, bold(item.profileName))
                  : item.profileName;
                const pointer = isCursor ? fg(cursorColor, "› ") : "  ";
                lines.push(row(`${pointer}${arrow} ${icon} ${name} ${count}${suffix}`));
              } else {
                const icon = item.active ? fg(activeColor, "✓") : fg(inactiveColor, "⊘");
                const name = isCursor
                  ? fg(cursorColor, item.skillName ?? "")
                  : item.skillName ?? "";
                const pointer = isCursor ? fg(cursorColor, "› ") : "  ";
                lines.push(row(`${pointer}    ${icon} ${name}`));
              }
            }

            if (total === 0) {
              lines.push(row(dim("  No profiles found in ~/.pi/agent/skill-profiles/")));
            }

            lines.push(emptyRow());

            // Scroll indicator
            if (total > maxVis) {
              lines.push(row(dim(`  ${cursorIndex + 1}/${total}`)));
              lines.push(emptyRow());
            }

            // Hints
            lines.push(row(dim("↑↓/jk navigate · enter expand · space toggle · q close")));
            lines.push(fg(border, "╰" + "─".repeat(innerW) + "╯"));

            return lines;
          },
        };
        return panel;
      },
      { overlay: true, overlayOptions: { anchor: "center", width: 56 } },
    );
  }

  async function triggerReload(ctx: ExtensionCommandContext): Promise<void> {
    if (typeof (ctx as any).reload === "function") {
      await (ctx as any).reload();
    } else {
      ctx.ui.notify("Run /reload to apply changes.", "info");
    }
  }
}
