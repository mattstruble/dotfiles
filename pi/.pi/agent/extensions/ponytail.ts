// ponytail — Pi extension
// Lazy-dev mode with intensity switching. Reads/writes mode from
// ~/.config/opencode/.ponytail-active (shared with opencode for cross-agent persistence).
// Finds ponytail SKILL.md via resources_discover skill paths.

import type {
  ExtensionAPI,
  ResourcesDiscoverEvent,
  ResourcesDiscoverResult,
  SessionStartEvent,
  BeforeAgentStartEvent,
  ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const CONFIG_HOME = process.env.XDG_CONFIG_HOME ?? join(process.env.HOME ?? "", ".config");
const MODE_FILE = join(CONFIG_HOME, "opencode", ".ponytail-active");

type Mode = "lite" | "full" | "ultra" | "off";
const VALID_MODES: Mode[] = ["lite", "full", "ultra", "off"];

function readMode(): Mode {
  try {
    const raw = readFileSync(MODE_FILE, "utf8").trim().toLowerCase();
    return (VALID_MODES.includes(raw as Mode) ? raw : "off") as Mode;
  } catch {
    return "off";
  }
}

function writeMode(mode: Mode): void {
  writeFileSync(MODE_FILE, mode, "utf8");
}

/** Scan skill paths for a ponytail/SKILL.md and return its body (frontmatter stripped). */
function findSkillContent(skillPaths: string[]): string {
  for (const base of skillPaths) {
    const candidate = join(base, "ponytail", "SKILL.md");
    try {
      const raw = readFileSync(candidate, "utf8");
      // Strip YAML frontmatter
      return raw.replace(/^---[\s\S]*?---\s*/, "").trim();
    } catch {
      // not here
    }
  }
  return "";
}

/** Collect all subdirectory paths under a skills root. */
function collectSkillPaths(root: string): string[] {
  try {
    return readdirSync(root)
      .filter((name) => {
        try { return statSync(join(root, name)).isDirectory(); } catch { return false; }
      })
      .map((name) => join(root, name));
  } catch {
    return [];
  }
}

export default function (pi: ExtensionAPI): void {
  let currentMode: Mode = readMode();
  // Skill paths discovered at session_start / resources_discover
  const knownSkillRoots: string[] = [];

  function getInstructions(): string {
    return findSkillContent(knownSkillRoots);
  }

  pi.on(
    "resources_discover",
    async (_event: ResourcesDiscoverEvent, _ctx): Promise<ResourcesDiscoverResult> => {
      // Contribute the ponytail skills directory so Pi can load ponytail sub-skills.
      const ponytailShare = join(process.env.HOME ?? "", ".local", "share", "ponytail");
      const ponytailSkillsRoot = join(ponytailShare, "skills");
      // Track for our own SKILL.md lookup
      if (!knownSkillRoots.includes(ponytailSkillsRoot)) {
        knownSkillRoots.push(ponytailSkillsRoot);
      }
      return { skillPaths: [ponytailSkillsRoot] };
    },
  );

  pi.on("session_start", async (_event: SessionStartEvent, _ctx) => {
    currentMode = readMode();
    // Also scan the global opencode skills dir as a fallback
    const opencodeSkills = join(CONFIG_HOME, "opencode", "skills");
    if (!knownSkillRoots.includes(opencodeSkills)) {
      knownSkillRoots.push(opencodeSkills);
    }
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<{ systemPrompt: string } | void> => {
      if (currentMode === "off") return;
      const instructions = getInstructions();
      if (!instructions) return;
      const base = event.systemPrompt ? `${event.systemPrompt}\n\n` : "";
      return { systemPrompt: `${base}${instructions}` };
    },
  );

  pi.registerCommand("ponytail", {
    description: "Set ponytail mode: lite | full | ultra | off | status",
    handler: async (args: string, ctx: ExtensionCommandContext) => {
      const arg = args.trim().toLowerCase();

      if (!arg || arg === "status") {
        ctx.ui.notify(`Ponytail: ${currentMode}`, "info");
        return;
      }

      if (VALID_MODES.includes(arg as Mode)) {
        currentMode = arg as Mode;
        writeMode(currentMode);
        ctx.ui.notify(`Ponytail mode: ${currentMode}`, "info");
        return;
      }

      ctx.ui.notify(`Unknown mode '${arg}'. Use: lite | full | ultra | off`, "warning");
    },
  });
}
