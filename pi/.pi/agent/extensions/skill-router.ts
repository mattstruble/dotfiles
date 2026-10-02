/**
 * skill-router — automatic skill injection and commit gate.
 *
 * Replaces skill-enforcer.ts. Per user turn at before_agent_start:
 *   1. Named-skill rule (score 1.0): catalog name found in the prompt text.
 *   2. Enforcer rule (score 0.75): pattern match on the prompt text.
 *   3. Sort hits by (score desc, name desc), keep top 2 with score >= 0.5.
 *   4. Drop skills already in context (injected, read via tool, explicit /skill).
 *   5. Inject remaining skill bodies as custom_message entries.
 *   6. Replace <available_skills> with a names-only list.
 *   7. Block git commit until git-commit is in context.
 *   8. Record each decision as a session entry for measurement.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, dirname } from "node:path";

// ── Config ──────────────────────────────────────────────────────────

interface DeciderConfig {
  url: string;
  model: string;
  timeoutMs: number;
  threshold: number;
  apiKeyEnv: string | null;
}

interface RouterConfig {
  mode: "inject" | "shadow" | "off";
  decider: DeciderConfig;
  catalog: string;
  maxSkillsPerTurn: number;
  maxSkillsPerTask: number;
}

const DEFAULT_CONFIG: RouterConfig = {
  mode: "inject",
  decider: {
    url: "http://127.0.0.1:8008",
    model: "kev-latest",
    timeoutMs: 1500,
    threshold: 0.30,
    apiKeyEnv: null,
  },
  catalog: "~/.pi/agent/skill-profiles/all",
  maxSkillsPerTurn: 2,
  maxSkillsPerTask: 3,
};

function expandTilde(p: string): string {
  if (p.startsWith("~/")) return join(process.env.HOME ?? "", p.slice(2));
  if (p === "~") return process.env.HOME ?? "";
  return p;
}

let _configWarnFired = false;
let _urlWarnFired = false;
let _apiKeyWarnFired = false;

const LOOPBACK_HOSTS = new Set(["127.0.0.1", "::1", "localhost"]);

/** Validate decider.url: must be http or https; plain http only for loopback. */
function validateDeciderUrl(url: string): { ok: boolean; disable: boolean; warn?: string } {
  let parsed: URL;
  try { parsed = new URL(url); } catch {
    return { ok: false, disable: true, warn: `invalid URL '${url}'` };
  }
  const scheme = parsed.protocol; // includes trailing colon
  if (scheme !== "http:" && scheme !== "https:") {
    return { ok: false, disable: true, warn: `scheme '${scheme}' not allowed (use http: or https:)` };
  }
  const host = parsed.hostname.replace(/^\[|\]$/g, "");
  if (scheme === "http:" && !LOOPBACK_HOSTS.has(host)) {
    return { ok: false, disable: true, warn: `plain http to non-loopback host '${host}' is not allowed` };
  }
  if (scheme === "https:" && !LOOPBACK_HOSTS.has(host)) {
    return { ok: true, disable: false, warn: `prompt text will leave the machine (https to ${host})` };
  }
  return { ok: true, disable: false };
}

function loadConfig(): RouterConfig {
  const configPath = join(process.env.HOME ?? "", ".pi/agent/skill-router.json");
  if (!existsSync(configPath)) return { ...DEFAULT_CONFIG, decider: { ...DEFAULT_CONFIG.decider } };
  try {
    const raw = JSON.parse(readFileSync(configPath, "utf-8"));
    if (typeof raw !== "object" || raw === null) {
      if (!_configWarnFired) {
        _configWarnFired = true;
        console.warn("[skill-router] config is not an object; using defaults");
      }
      return { ...DEFAULT_CONFIG, decider: { ...DEFAULT_CONFIG.decider } };
    }
    const cfg: RouterConfig = { ...DEFAULT_CONFIG, decider: { ...DEFAULT_CONFIG.decider } };
    const badFields: string[] = [];

    // mode
    if (raw.mode === "inject" || raw.mode === "shadow" || raw.mode === "off") {
      cfg.mode = raw.mode;
    } else if (raw.mode !== undefined) {
      badFields.push("mode");
    }

    // maxSkillsPerTurn
    if (typeof raw.maxSkillsPerTurn === "number" && raw.maxSkillsPerTurn > 0) {
      cfg.maxSkillsPerTurn = raw.maxSkillsPerTurn;
    } else if (raw.maxSkillsPerTurn !== undefined) {
      badFields.push("maxSkillsPerTurn");
    }

    // maxSkillsPerTask
    if (typeof raw.maxSkillsPerTask === "number" && raw.maxSkillsPerTask > 0) {
      cfg.maxSkillsPerTask = raw.maxSkillsPerTask;
    } else if (raw.maxSkillsPerTask !== undefined) {
      badFields.push("maxSkillsPerTask");
    }

    // catalog
    if (typeof raw.catalog === "string" && raw.catalog.length > 0) {
      cfg.catalog = raw.catalog;
    } else if (raw.catalog !== undefined) {
      badFields.push("catalog");
    }

    // decider
    if (typeof raw.decider === "object" && raw.decider !== null) {
      const d = raw.decider;
      const dc = { ...DEFAULT_CONFIG.decider };
      if (typeof d.url === "string" && d.url.length > 0) dc.url = d.url;
      else if (d.url !== undefined) badFields.push("decider.url");
      if (typeof d.model === "string" && d.model.length > 0) dc.model = d.model;
      else if (d.model !== undefined) badFields.push("decider.model");
      if (typeof d.timeoutMs === "number" && d.timeoutMs > 0) dc.timeoutMs = d.timeoutMs;
      else if (d.timeoutMs !== undefined) badFields.push("decider.timeoutMs");
      if (typeof d.threshold === "number" && d.threshold >= 0 && d.threshold <= 1) dc.threshold = d.threshold;
      else if (d.threshold !== undefined) badFields.push("decider.threshold");
      if (d.apiKeyEnv === null || (typeof d.apiKeyEnv === "string")) dc.apiKeyEnv = d.apiKeyEnv;
      else if (d.apiKeyEnv !== undefined) badFields.push("decider.apiKeyEnv");
      cfg.decider = dc;
    } else if (raw.decider !== undefined) {
      badFields.push("decider");
    }

    // Report all invalid fields in one warning
    if (badFields.length > 0 && !_configWarnFired) {
      _configWarnFired = true;
      console.warn(`[skill-router] invalid config fields: ${badFields.join(", ")}; using defaults for those`);
    }

    // Validate decider URL
    const urlCheck = validateDeciderUrl(cfg.decider.url);
    if (urlCheck.warn && !_urlWarnFired) {
      _urlWarnFired = true;
      console.warn(`[skill-router] decider.url: ${urlCheck.warn}`);
    }
    if (urlCheck.disable) {
      cfg.decider.url = "";
    }

    // Warn if apiKeyEnv is set but the env var is empty/unset
    if (cfg.decider.apiKeyEnv) {
      const val = process.env[cfg.decider.apiKeyEnv];
      if (!val && !_apiKeyWarnFired) {
        _apiKeyWarnFired = true;
        console.warn(`[skill-router] apiKeyEnv '${cfg.decider.apiKeyEnv}' is set but the environment variable is empty or unset`);
      }
    }

    return cfg;
  } catch {
    if (!_configWarnFired) {
      _configWarnFired = true;
      console.warn("[skill-router] invalid JSON in config; using defaults");
    }
    return { ...DEFAULT_CONFIG, decider: { ...DEFAULT_CONFIG.decider } };
  }
}

// ── Module-level config ─────────────────────────────────────────────
let _config = loadConfig();

/** Replace the active config. For testing only. */
function _setConfig(cfg: RouterConfig): void { _config = cfg; }
/** Return the active config. */
function _getConfig(): RouterConfig { return _config; }

const MAX_STATE_CHARS = 2000;
const SCORE_NAMED = 1.0;
const SCORE_ENFORCER = 0.75;
const MIN_SCORE = 0.5;
const CUSTOM_TYPE = "skill-router";
const DECISION_ENTRY = "skill-router-decision";
const GIT_COMMIT_SKILL_MARKER = "[skill-router] git-commit skill loaded for this commit:";

// ── Commit-gate command introspection ────────────────────────────────
//
// Ceiling: shell-lite scan, not a real parser. For example, `bash <<EOF`
// bodies that do run are not seen after stripping.

/**
 * Strip shell constructs that are not executed as commands:
 *   - Heredoc bodies (<<EOF ... EOF, <<'EOF', <<-EOF, <<"EOF")
 *   - Single-quoted string contents
 *   - Double-quoted string contents
 *   - # comments (outside quotes)
 * Returns the remaining text for command-position scanning.
 */
function stripShellNonCommands(cmd: string): string {
  // Phase 1: strip heredoc bodies.  We look for <<[-]?['"]?WORD['"]? and
  // remove everything from the next newline up to and including the line
  // matching the bare delimiter.
  let result = cmd;
  const heredocRe = /<<-?\s*['"]?(\w+)['"]?/g;
  let hm: RegExpExecArray | null;
  // Process from last to first so indices stay valid
  const heredocs: Array<{ start: number; end: number }> = [];
  while ((hm = heredocRe.exec(result)) !== null) {
    const delim = hm[1];
    const afterOp = hm.index + hm[0].length;
    const nlPos = result.indexOf("\n", afterOp);
    if (nlPos === -1) continue;
    const bodyStart = nlPos; // include the newline
    const endRe = new RegExp(`^${delim}\\s*$`, "m");
    const bodySlice = result.slice(nlPos + 1);
    const endMatch = endRe.exec(bodySlice);
    if (!endMatch) continue;
    const bodyEnd = nlPos + 1 + endMatch.index + endMatch[0].length;
    heredocs.push({ start: bodyStart, end: bodyEnd });
  }
  // Remove from last to first
  for (let i = heredocs.length - 1; i >= 0; i--) {
    result = result.slice(0, heredocs[i].start) + result.slice(heredocs[i].end);
  }

  // Phase 2: strip single-quoted strings, double-quoted strings, and comments.
  // Walk character by character.
  let out = "";
  let i = 0;
  while (i < result.length) {
    const ch = result[i];
    if (ch === "$" && i + 1 < result.length && result[i + 1] === "'") {
      // ANSI-C $'...' string: skip content, honoring backslash escapes
      let j = i + 2;
      while (j < result.length) {
        if (result[j] === "\\" ) { j += 2; continue; }
        if (result[j] === "'") break;
        j++;
      }
      i = j + 1;
      continue;
    }
    if (ch === "'" ) {
      // Single-quoted string: skip to closing '
      const end = result.indexOf("'", i + 1);
      if (end === -1) { i++; continue; }
      i = end + 1;
      continue;
    }
    if (ch === '"') {
      // Double-quoted string: skip to closing " (respecting \")
      let j = i + 1;
      while (j < result.length) {
        if (result[j] === "\\" ) { j += 2; continue; }
        if (result[j] === '"') break;
        j++;
      }
      i = j + 1;
      continue;
    }
    if (ch === "#") {
      // Comment: skip to end of line
      const eol = result.indexOf("\n", i);
      if (eol === -1) break;
      i = eol; // keep the newline
      continue;
    }
    out += ch;
    i++;
  }
  return out;
}

/**
 * Detect a real `git commit` invocation at a command position in a shell
 * command string.  Strips non-command text, splits into command segments,
 * then matches git plus global options plus `commit`.
 */
function isRealGitCommit(cmd: string): boolean {
  const stripped = stripShellNonCommands(cmd);
  // Split on command boundaries
  const segments = stripped.split(/[;\n]|&&|\|\||\|/);
  for (const seg of segments) {
    // Also split on ( and $( — use a secondary split
    const subsegments = seg.split(/\(/);
    for (const sub of subsegments) {
      if (testSegmentForGitCommit(sub.trim())) return true;
    }
  }
  return false;
}

/** Test a single command segment (already split on boundaries) for git commit. */
function testSegmentForGitCommit(seg: string): boolean {
  // Strip leading VAR=value assignments
  let s = seg;
  while (/^\w+=\S*\s/.test(s)) {
    s = s.replace(/^\w+=\S*\s+/, "");
  }
  // Strip optional command wrappers
  while (/^(?:sudo|env|command|exec)\s/.test(s)) {
    s = s.replace(/^(?:sudo|env|command|exec)\s+/, "");
  }
  // Must start with "git" now
  if (!s.startsWith("git") || (s.length > 3 && /\w/.test(s[3]))) return false;
  // Walk past "git" and consume global options to find the subcommand
  let rest = s.slice(3).trimStart();
  // Consume global options
  while (rest.length > 0) {
    // Options that take a value: -C <path>, -c <key=value>
    const shortOpt = rest.match(/^-[CcP]\s+\S+\s*/);
    if (shortOpt) { rest = rest.slice(shortOpt[0].length).trimStart(); continue; }
    // --option=value
    const longOptEq = rest.match(/^--[a-z][a-z0-9-]+=\S*\s*/);
    if (longOptEq) { rest = rest.slice(longOptEq[0].length).trimStart(); continue; }
    // --option <value> (for known options that take a separate arg)
    const longOptSep = rest.match(/^--(?:git-dir|work-tree|exec-path|namespace)\s+\S+\s*/);
    if (longOptSep) { rest = rest.slice(longOptSep[0].length).trimStart(); continue; }
    // Boolean long options
    const longBool = rest.match(/^--(?:no-pager|bare|paginate|no-replace-objects|literal-pathspecs|glob-pathspecs|noglob-pathspecs|no-optional-locks)\s*/);
    if (longBool) { rest = rest.slice(longBool[0].length).trimStart(); continue; }
    // -P (alias for --no-pager)
    if (rest.startsWith("-P") && (rest.length === 2 || /\s/.test(rest[2]))) {
      rest = rest.slice(2).trimStart(); continue;
    }
    break;
  }
  // The next word should be the subcommand
  const subCmd = rest.match(/^(\S+)/);
  return subCmd !== null && subCmd[1] === "commit";
}

// ── Enforcer patterns (same list as run_models.py ENFORCER) ─────────
const ENFORCER: Array<{ pattern: RegExp; skill: string }> = [
  { pattern: /\b(commit|amend|git add|stage|unstage|git push)\b/i, skill: "git-commit" },
  { pattern: /\b(pull request|create.*pr|open.*pr|gh pr)\b/i, skill: "git-pr" },
  { pattern: /\b(implement|refactor|design|architect|write.*code|add.*feature|build.*feature)\b/i, skill: "software-design" },
  { pattern: /\b(write.*test|add.*test|test.*coverage|unit test|integration test|tdd)\b/i, skill: "test-design" },
  { pattern: /\b(dockerfile|docker.compose|docker compose|container|build.*image|containerize)\b/i, skill: "docker" },
  { pattern: /\b(helm|helm chart|values\.yaml|helmfile|helm template)\b/i, skill: "helm" },
  { pattern: /\b(nix|flake\.nix|derivation|nixos|nix-darwin|darwin-rebuild|home-manager|nixpkgs)\b/i, skill: "nix" },
  { pattern: /\b(python|\.py|pydantic|fastapi|django|flask|pytest|pyproject)\b/i, skill: "python-design" },
  { pattern: /\b(api design|rest api|grpc|openapi|swagger|resource model|endpoint design|api spec)\b/i, skill: "api-design" },
  { pattern: /\b(code review|review.*pr|review.*diff|review.*changes|lgtm)\b/i, skill: "code-reviewer" },
];

// ── Language-to-skill map for coding task detection (extensions, filenames, and marker files) ──
const LANGUAGE_MAP: Array<{ patterns: RegExp[]; markers: string[]; skill: string }> = [
  { patterns: [/\.py\b/], markers: ["pyproject.toml", "setup.py", "requirements.txt"], skill: "python-design" },
  { patterns: [/\.nix\b/], markers: ["flake.nix"], skill: "nix" },
  { patterns: [/Dockerfile\b/, /docker-compose\.yml\b/, /compose\.yaml\b/], markers: ["Dockerfile", "docker-compose.yml", "compose.yaml"], skill: "docker" },
  { patterns: [/Chart\.yaml\b/], markers: ["Chart.yaml"], skill: "helm" },
  { patterns: [/\.odin\b/], markers: [], skill: "odin-design" },
  { patterns: [/\.gd\b/, /\.tscn\b/, /project\.godot\b/], markers: ["project.godot"], skill: "godot" },
  { patterns: [/\.gdshader\b/], markers: [], skill: "godot-shader" },
  { patterns: [/\.fnl\b/], markers: [], skill: "love2d-fennel" },
  { patterns: [/conf\.lua\b/, /main\.lua\b/], markers: ["conf.lua", "main.lua"], skill: "love2d" },
];

/** A task is a coding task when it has write/edit tools or sets worktree/allowTreeMutation. */
function isCodingTask(task: any): boolean {
  if (Array.isArray(task.tools)) {
    for (const t of task.tools) {
      const name = typeof t === "string" ? t : t?.name;
      if (name === "write" || name === "edit") return true;
    }
  }
  if (task.worktree === true || task.allowTreeMutation === true) return true;
  return false;
}

/** Extract the repo root from "Repo root: <path>" in task text, or fall back to dir. */
function resolveRepoRoot(taskText: string, fallbackDir: string): string {
  const m = taskText.match(/Repo root:\s*(.+)/m);
  if (m) {
    const candidate = m[1].trim();
    try {
      if (statSync(candidate).isDirectory()) return candidate;
    } catch { /* fall through */ }
  }
  return fallbackDir;
}

/** Detect language skills from file references in text and marker files at repo top level. */
function detectLanguages(
  taskText: string,
  repoRoot: string,
  catalogNameSet: Set<string>,
): string[] {
  const detected = new Set<string>();

  // Check text for file patterns
  for (const entry of LANGUAGE_MAP) {
    for (const pat of entry.patterns) {
      if (pat.test(taskText)) {
        if (catalogNameSet.has(entry.skill)) detected.add(entry.skill);
        break;
      }
    }
  }

  // Check marker files at repo top level (single readdir, no recursion)
  try {
    const topFiles = new Set(readdirSync(repoRoot));
    for (const entry of LANGUAGE_MAP) {
      if (detected.has(entry.skill)) continue;
      for (const marker of entry.markers) {
        if (topFiles.has(marker)) {
          if (catalogNameSet.has(entry.skill)) detected.add(entry.skill);
          break;
        }
      }
    }
  } catch { /* repo dir unreadable — skip marker detection */ }

  return [...detected];
}

// ── Catalog ─────────────────────────────────────────────────────────

interface CatalogEntry {
  name: string;
  description: string;
  location: string;
  body: string;
}

function parseFrontmatter(text: string, key: string): string {
  const m = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n/);
  if (!m) return "";
  const lines = m[1].split("\n");
  for (let i = 0; i < lines.length; i++) {
    const mm = lines[i].match(new RegExp(`^${key}:\\s*(.*)`));
    if (!mm) continue;
    let v = mm[1].trim();
    if (v === ">" || v === "|" || v === ">-" || v === "|-" || v === ">+" || v === "|+") {
      const fold = v.startsWith(">");
      const body: string[] = [];
      for (let j = i + 1; j < lines.length; j++) {
        if (lines[j].trim() && !lines[j].startsWith(" ") && !lines[j].startsWith("\t")) break;
        body.push(lines[j].trim());
      }
      return body.filter(Boolean).join(fold ? " " : "\n").trim();
    }
    if (!v) return "";
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    return v.replace(/\\"/g, '"');
  }
  return "";
}

function loadCatalog(catalogDir?: string): Map<string, CatalogEntry> {
  const dir = catalogDir ?? expandTilde(_config.catalog);
  const catalog = new Map<string, CatalogEntry>();
  try {
    for (const name of readdirSync(dir).sort()) {
      const loc = join(dir, name, "SKILL.md");
      if (!existsSync(loc)) continue;
      try {
        const body = readFileSync(loc, "utf-8");
        const desc = parseFrontmatter(body, "description");
        catalog.set(name, { name, description: desc, location: loc, body });
      } catch { /* skip unreadable */ }
    }
  } catch { /* catalog dir missing */ }
  return catalog;
}

// ── Named-skill regex builder (mirrors run_models.rule_probs) ───────

function buildNameRegex(name: string): RegExp {
  // Escape regex special chars, then replace every hyphen with [- ] so
  // "git-pr" matches both "git-pr" and "git pr" (mirrors Python
  // re.escape(n).replace('\\-', '[- ]')).
  const escaped = name
    .replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    .replace(/-/g, "[- ]");
  return new RegExp(`(?<![\\w-])${escaped}(?![\\w-])`, "i");
}

// ── Explicit-turn detection (mirrors inject_eval.py explicit_skills) ─

function isExplicitTurn(text: string, catalogNames: Set<string>): boolean {
  if (text.includes("<skill") || text.includes("SKILL.md")) return true;
  if (/(?:^|\s)\/skill:[\w-]/.test(text)) return true;
  const first = text.trim().split(/\s+/)[0];
  if (first) {
    const bare = first.replace(/^\//, "");
    if (catalogNames.has(bare)) return true;
  }
  return false;
}

// ── Rule scoring ────────────────────────────────────────────────────

function scorePrompt(
  text: string,
  catalogNames: string[],
  catalogNameSet?: Set<string>,
): Map<string, number> {
  const scores = new Map<string, number>();
  const truncated = text.slice(0, MAX_STATE_CHARS);

  // Named-skill rule: catalog name found in prompt → 1.0
  for (const name of catalogNames) {
    if (buildNameRegex(name).test(truncated)) {
      scores.set(name, SCORE_NAMED);
    }
  }

  // Enforcer rule: pattern match → 0.75, but only for catalog names
  const nameSet = catalogNameSet ?? new Set(catalogNames);
  for (const { pattern, skill } of ENFORCER) {
    if (!nameSet.has(skill)) continue;
    if (pattern.test(truncated) && !scores.has(skill)) {
      scores.set(skill, SCORE_ENFORCER);
    }
  }

  return scores;
}

// ── Selection (mirrors inject_eval.py pick) ─────────────────────────

function selectSkills(
  scores: Map<string, number>,
  inContext: Set<string>,
  maxSkills?: number,
): Array<{ name: string; score: number }> {
  const topK = maxSkills ?? _config.maxSkillsPerTurn;
  const ranked = [...scores.entries()]
    .filter(([, v]) => v >= MIN_SCORE)
    .sort((a, b) => b[1] - a[1] || (b[0] > a[0] ? 1 : b[0] < a[0] ? -1 : 0))
    .slice(0, topK);
  return ranked
    .filter(([n]) => !inContext.has(n))
    .map(([name, score]) => ({ name, score }));
}

// ── In-context skill detection ──────────────────────────────────────
//
// Pi 0.84.2 entry shapes (from session-manager.js):
//
// Router injections (via before_agent_start → result.message):
//   { type: "custom_message", customType: "skill-router",
//     content: "<skill name=\"...\">...</skill>", display: false, details: ... }
//   The content string contains <skill name="..."> tags with the skill bodies.
//   No `data` field — the session stores customType, content, display, details.
//
// Decision entries (via pi.appendEntry):
//   { type: "custom", customType: "skill-router-decision",
//     data: { hits, inContext, injected, explicit } }
//   These are NOT in context (they are metadata entries).
//
// User messages:
//   { type: "message", message: { role: "user",
//     content: [{ type: "text", text: "..." }] } }
//
// Assistant tool calls:
//   { type: "message", message: { role: "assistant",
//     content: [{ type: "toolCall", name: "read",
//                  arguments: { path: "..." } }, ...] } }
//
// Compaction:
//   { type: "compaction", summary: "...", firstKeptEntryId: "...", ... }
//   buildContextEntries() applies the compaction cut.

function skillsInContext(entries: any[]): Set<string> {
  const names = new Set<string>();
  for (const entry of entries) {
    if (!entry) continue;

    // Router custom_message entries: parse <skill name="..."> from content
    if (entry.type === "custom_message" && entry.customType === CUSTOM_TYPE) {
      const content = typeof entry.content === "string" ? entry.content : "";
      for (const match of content.matchAll(/<skill name="([^"]+)"/g)) {
        names.add(match[1]);
      }
      continue;
    }

    // Message entries (user, assistant, toolResult)
    if (entry.type === "message" && entry.message) {
      const msg = entry.message;

      // Assistant tool calls: detect SKILL.md reads
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block?.type === "toolCall") {
            const args = block.arguments ?? block.input ?? {};
            const path = typeof args === "string" ? args : args.path ?? "";
            const m = path.match(/skill-profiles\/[^/]+\/([^/]+)\/SKILL\.md/);
            if (m) names.add(m[1]);
          }
        }
      }

      // User messages: detect /skill: and <skill name="..."> references
      if (msg.role === "user") {
        const textParts: string[] = [];
        if (typeof msg.content === "string") {
          textParts.push(msg.content);
        } else if (Array.isArray(msg.content)) {
          for (const block of msg.content) {
            if (typeof block === "string") textParts.push(block);
            else if (block?.type === "text" && typeof block.text === "string") {
              textParts.push(block.text);
            }
          }
        }
        for (const text of textParts) {
          for (const match of text.matchAll(/<skill name="([^"]+)"/g)) {
            names.add(match[1]);
          }
          for (const match of text.matchAll(/\/skill:([\w-]+)/g)) {
            names.add(match[1]);
          }
        }
      }

      // toolResult messages: detect the git-commit skill marker.
      // Only count when isError === true and the text *starts with* the
      // marker (a model could echo the marker in a successful result).
      if (msg.role === "toolResult" && msg.isError === true && Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block?.type === "text" && typeof block.text === "string") {
            if (block.text.startsWith(GIT_COMMIT_SKILL_MARKER)) {
              names.add("git-commit");
            }
          }
        }
      }
    }
  }
  return names;
}

// ── Injection message format ────────────────────────────────────────

function formatSkillMessage(entry: CatalogEntry): string {
  const baseDir = dirname(entry.location);
  return `<skill name="${entry.name}" location="${entry.location}">\nReferences are relative to ${baseDir}.\n\n${entry.body}\n</skill>`;
}

// ── Names-only skill list ───────────────────────────────────────────

function buildNamesOnlyList(catalog: Map<string, CatalogEntry>): string {
  const names = [...catalog.keys()].sort();
  const root = expandTilde(_config.catalog);
  // Pick a real example skill name for the path pattern
  const exampleName = catalog.has("git-commit") ? "git-commit" : (names[0] ?? "example");
  // Leading empty strings produce "\n\n" after join("\n"), separating this
  // block from whatever precedes it when spliced into the system prompt.
  const lines: string[] = [
    "",
    "",
    "The following skills provide specialized instructions for specific tasks. When a skill name matches the task you are doing, read the SKILL.md at the listed location to load the full instructions. When a SKILL.md references a relative path, resolve it against the skill directory (parent of SKILL.md / dirname of the path) and use that absolute path in tool commands.",
    "",
    `Each skill is at ${root}/<skill>/SKILL.md, for example ${root}/${exampleName}/SKILL.md. Skills:`,
  ];
  // Wrap at ~80 columns
  let buf = "  ";
  for (let i = 0; i < names.length; i++) {
    const piece = (buf === "  " ? "" : ", ") + names[i];
    if (buf.length > 2 && buf.length + piece.length > 80) {
      lines.push(`${buf},`);
      buf = `  ${names[i]}`;
    } else {
      buf += piece;
    }
  }
  if (buf.length > 2) lines.push(buf);
  return lines.join("\n");
}

// ── System prompt transform ─────────────────────────────────────────

function replaceSkillsBlock(prompt: string, namesOnlyBlock: string): string {
  // Strategy: detect and replace whichever form is present.
  // Form 1: Pi's verbose <available_skills>...</available_skills> XML block, including its
  // preamble. Pi <=0.98 put two newlines before the preamble; 0.99 renders it trimmed inside
  // a <skills> section, so a single newline precedes it.
  const xmlMatch = prompt.match(
    /\n+The following skills provide specialized instructions[\s\S]*?<\/available_skills>/,
  );
  if (xmlMatch) {
    return prompt.replace(xmlMatch[0], namesOnlyBlock);
  }

  // Form 2: pi-cache-optimizer's compressed "Skills under ..." or "Each skill is at ..." form
  // (preamble + grouped name lists)
  const compressedMatch = prompt.match(
    /\n+The following skills provide specialized instructions[\s\S]*?(?=\n\n(?!(?:Skills under |Each skill is at ))|\n<\/skills>|$)/,
  );
  if (compressedMatch) {
    return prompt.replace(compressedMatch[0], namesOnlyBlock);
  }

  // No recognized skill block — append our list
  return prompt + namesOnlyBlock;
}

// ── Context entry retrieval ─────────────────────────────────────────

/**
 * Get the compaction-aware context entries from the session manager.
 * Uses buildContextEntries() which respects compaction cuts, falling
 * back to getBranch() if the method is unavailable.
 */
function getContextEntries(ctx: any): any[] {
  const sm = ctx?.sessionManager;
  if (!sm) return [];
  // Prefer buildContextEntries (compaction-aware)
  if (typeof sm.buildContextEntries === "function") {
    return sm.buildContextEntries();
  }
  // Fallback: getBranch returns the full path (no compaction cut)
  if (typeof sm.getBranch === "function") {
    return sm.getBranch();
  }
  return [];
}

// ── Kev filter ──────────────────────────────────────────────────────

interface KevResult {
  ok: boolean;
  probs: Record<string, number>; // skill → p
}

/**
 * Query Kev with a pre-built state string. This is the single implementation;
 * queryKev (below) builds the state and delegates here.
 */
async function queryKevWithState(
  hits: Map<string, number>,
  catalog: Map<string, CatalogEntry>,
  state: string,
  cfg: RouterConfig,
): Promise<KevResult> {
  if (hits.size === 0) return { ok: true, probs: {} };

  const questions: Record<string, any> = {};
  for (const [name] of hits) {
    const entry = catalog.get(name);
    const desc = entry?.description?.slice(0, 400) ?? "";
    questions[name] = {
      type: "noul",
      instructions: `Would a careful coding agent load the \`${name}\` skill before handling this request? Skill description: ${desc}`,
      criteria: {
        true: "The request's task clearly matches this skill's stated purpose",
        false: "The skill is unrelated or only tangential to the request",
      },
    };
  }

  const body = { state, model: cfg.decider.model, questions };
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (cfg.decider.apiKeyEnv) {
    const key = process.env[cfg.decider.apiKeyEnv];
    if (key) headers["Authorization"] = `Bearer ${key}`;
  }

  const url = cfg.decider.url;
  if (!url) throw new Error("decider URL is disabled");

  const resp = await fetch(`${url}/v1/systemone`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(cfg.decider.timeoutMs),
  });

  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

  let data: any;
  try {
    data = await resp.json();
  } catch {
    throw new Error("non-JSON response body");
  }
  if (!data?.answers || typeof data.answers !== "object") {
    throw new Error("malformed response: missing answers");
  }

  const probs: Record<string, number> = {};
  for (const [name] of hits) {
    const ans = data.answers[name];
    if (ans && typeof ans.noul === "number" && Number.isFinite(ans.noul) && ans.noul >= 0 && ans.noul <= 1) {
      probs[name] = ans.noul;
    } else {
      throw new Error(`invalid noul for ${name}: ${JSON.stringify(ans?.noul)}`);
    }
  }
  return { ok: true, probs };
}

/** Convenience wrapper: builds the state string from cwd + prompt, then calls queryKevWithState. */
async function queryKev(
  hits: Map<string, number>,
  catalog: Map<string, CatalogEntry>,
  prompt: string,
  cfg: RouterConfig,
): Promise<KevResult> {
  const cwd = process.cwd().replace(process.env.HOME ?? "", "~");
  const state = `Working directory: ${cwd}\nUser request:\n${prompt.slice(0, 2000)}`;
  return queryKevWithState(hits, catalog, state, cfg);
}

// ── Selection with Kev scores ───────────────────────────────────────

/**
 * Select skills using Kev probabilities. `ruleHitNames` is the set of
 * skill names that matched rules — their rule scores are intentionally
 * ignored because Kev’s p replaces them (same as the evaluation harness).
 */
function selectSkillsWithKev(
  ruleHitNames: ReadonlySet<string>,
  kevProbs: Record<string, number>,
  inContext: Set<string>,
  threshold: number,
  maxSkills: number,
): Array<{ name: string; score: number }> {
  const entries: Array<{ name: string; score: number }> = [];
  for (const name of ruleHitNames) {
    const p = kevProbs[name] ?? 0;
    if (p < threshold) continue;
    entries.push({ name, score: 1.0 + p });
  }
  entries.sort((a, b) => b.score - a.score || (b.name > a.name ? 1 : b.name < a.name ? -1 : 0));
  return entries
    .slice(0, maxSkills)
    .filter(({ name }) => !inContext.has(name));
}

// ── Kev-then-rules fallback helper ──────────────────────────────────

interface KevFallbackResult {
  toInject: Array<{ name: string; score: number }>;
  kevStatus: "ok" | "failed" | "skipped";
  probs: Record<string, number>;
}

/**
 * Try Kev filter on rule hits; on any failure fall back to rules-only.
 * Used by both before_agent_start and routeSubagentSkills.
 */
async function kevThenRules(
  hits: Map<string, number>,
  catalog: Map<string, CatalogEntry>,
  state: string,
  inContext: Set<string>,
  cfg: RouterConfig,
): Promise<KevFallbackResult> {
  try {
    const kev = await queryKevWithState(hits, catalog, state, cfg);
    return {
      toInject: selectSkillsWithKev(
        new Set(hits.keys()), kev.probs, inContext,
        cfg.decider.threshold, cfg.maxSkillsPerTurn,
      ),
      kevStatus: "ok",
      probs: kev.probs,
    };
  } catch {
    if (!_kevWarnFired) {
      _kevWarnFired = true;
      console.warn("[skill-router] Kev decider unavailable; using rules-only selection");
    }
    return {
      toInject: selectSkills(hits, inContext),
      kevStatus: "failed",
      probs: {},
    };
  }
}

// ── Subagent task routing ───────────────────────────────────────────

/** Collect every object carrying a string `task` from single, tasks[] and chain (incl. parallel) shapes. */
function collectSubagentTasks(input: any): any[] {
  const out: any[] = [];
  const add = (t: any) => { if (t && typeof t.task === "string") out.push(t); };
  if (!input || typeof input !== "object") return out;
  add(input);
  if (Array.isArray(input.tasks)) input.tasks.forEach(add);
  if (Array.isArray(input.chain)) {
    for (const step of input.chain) {
      if (Array.isArray(step?.parallel)) step.parallel.forEach(add);
      else add(step);
    }
  }
  return out;
}

/** Normalize a subagent `skill` value (array or CSV string) to a name list. */
function existingSkillNames(skill: unknown): string[] {
  if (Array.isArray(skill)) return skill.filter((x): x is string => typeof x === "string");
  if (typeof skill === "string") return skill.split(",").map((x) => x.trim()).filter(Boolean);
  return [];
}

/**
 * Route a subagent call: score all task texts first, then query Kev concurrently
 * (one request per task-with-hits, all in parallel via Promise.allSettled),
 * so total wall-clock is bounded by ~1× timeoutMs rather than N× timeoutMs.
 * Picked skill names are merged into the top-level `skill` field (which
 * subagent only supports call-wide); `skill: false` is left alone.
 */
async function routeSubagentSkills(
  input: any,
  catalog: Map<string, CatalogEntry>,
  catalogNames: string[],
  catalogNameSet: Set<string>,
  pi: ExtensionAPI,
  ctx: any,
): Promise<void> {
  if (!input || typeof input !== "object" || input.skill === false) return;
  const tasks = collectSubagentTasks(input);
  const existing = existingSkillNames(input.skill);
  // Snapshot before routing: `existing` grows as picks are written, but
  // per-task dedupe must only see skills that were present up front.
  const initialSkills = [...existing];
  const cwdRaw = ctx?.cwd ?? process.cwd();
  const cwd = cwdRaw.replace(process.env.HOME ?? "", "~");

  // Phase 1: score all tasks synchronously
  interface ScoredTask {
    index: number;
    task: any;
    hits: Map<string, number>;
    alreadyPresent: Set<string>;
    state: string;
    coding: boolean;
    languages: string[];
  }
  const scored: ScoredTask[] = [];

  for (let i = 0; i < tasks.length; i++) {
    const task = tasks[i];
    if (!task || typeof task.task !== "string") continue;

    try {
      const taskText = task.task;
      const truncated = taskText.slice(0, MAX_STATE_CHARS);

      if (isExplicitTurn(truncated, catalogNameSet)) continue;

      const coding = isCodingTask(task);
      let languages: string[] = [];

      if (coding) {
        const repoRoot = resolveRepoRoot(taskText, cwdRaw);
        languages = detectLanguages(taskText, repoRoot, catalogNameSet);
      }

      const hits = scorePrompt(taskText, catalogNames, catalogNameSet);

      // Non-coding tasks with no hits can be skipped entirely
      if (!coding && hits.size === 0) continue;

      const alreadyPresent = new Set<string>();
      for (const name of initialSkills) alreadyPresent.add(name);
      for (const match of taskText.matchAll(/<skill name="([^"]+)"/g)) {
        alreadyPresent.add(match[1]);
      }

      const state = `Working directory: ${cwd}\nUser request:\n${truncated}`;
      scored.push({ index: i, task, hits, alreadyPresent, state, coding, languages });
    } catch {
      continue;
    }
  }

  if (scored.length === 0) return;

  // Phase 2: query Kev concurrently for all scored tasks (only for tasks with rule hits)
  const results = await Promise.allSettled(
    scored.map((s) =>
      s.hits.size > 0
        ? kevThenRules(s.hits, catalog, s.state, s.alreadyPresent, _config)
        : Promise.resolve({ toInject: [], kevStatus: "skipped" as const, probs: {} } as KevFallbackResult)
    ),
  );

  // Phase 3: apply results
  for (let j = 0; j < scored.length; j++) {
    const s = scored[j];
    const settled = results[j];
    const fb: KevFallbackResult = settled.status === "fulfilled"
      ? settled.value
      : { toInject: selectSkills(s.hits, s.alreadyPresent), kevStatus: "failed" as const, probs: {} };

    // Build final injection list
    let toInject: Array<{ name: string; score: number }>;

    if (s.coding) {
      // Coding tasks: language skills + software-design first (skip Kev), then Kev/rules picks
      const langSkills: Array<{ name: string; score: number }> = [];
      for (const lang of s.languages) {
        if (!s.alreadyPresent.has(lang)) {
          langSkills.push({ name: lang, score: 2.0 }); // high score to sort first
        }
      }
      if (catalogNameSet.has("software-design") && !s.alreadyPresent.has("software-design")) {
        langSkills.push({ name: "software-design", score: 1.99 });
      }

      // Merge: language+software-design first, then Kev/rules picks, dedup
      const seen = new Set(langSkills.map((sk) => sk.name));
      const merged = [...langSkills];
      for (const sk of fb.toInject) {
        if (!seen.has(sk.name) && !s.alreadyPresent.has(sk.name)) {
          seen.add(sk.name);
          merged.push(sk);
        }
      }
      toInject = merged.slice(0, _config.maxSkillsPerTask);
    } else {
      // Non-coding tasks: same as before
      toInject = fb.toInject;
    }

    // Shadow mode: log but don't mutate
    if (_config.mode === "shadow") {
      try {
        pi.appendEntry(DECISION_ENTRY, {
          subagent: true,
          taskIndex: s.index,
          mode: "shadow" as const,
          coding: s.coding,
          languages: s.languages,
          kev: fb.kevStatus,
          probs: fb.probs,
          wouldInject: toInject.map((sk) => sk.name),
          hits: Object.fromEntries(s.hits),
        });
      } catch { /* never fail for logging */ }
      continue;
    }

    // Inject mode: merge skill names into the top-level `skill` field
    if (toInject.length === 0) continue;
    const names = toInject.map((sk) => sk.name).filter((n) => catalogNameSet.has(n));
    if (names.length === 0) continue;
    for (const n of names) if (!existing.includes(n)) existing.push(n);
    input.skill = [...existing];

    try {
      pi.appendEntry(DECISION_ENTRY, {
        subagent: true,
        taskIndex: s.index,
        mode: "inject" as const,
        coding: s.coding,
        languages: s.languages,
        kev: fb.kevStatus,
        probs: fb.probs,
        hits: Object.fromEntries(s.hits),
        injected: toInject.map((sk) => sk.name),
      });
    } catch { /* never fail for logging */ }
  }
}

// ── Extension entry point ───────────────────────────────────────────

let _sessionWarnFired = false;
let _kevWarnFired = false;

export default function (pi: ExtensionAPI) {
  const catalog = loadCatalog();
  const catalogNames = [...catalog.keys()];
  const catalogNameSet = new Set(catalogNames);
  const namesOnlyBlock = buildNamesOnlyList(catalog);

  // Inject skill directives and transform system prompt
  pi.on("before_agent_start", async (event, ctx) => {
    // Off mode: commit gate still active, but routing does nothing
    if (_config.mode === "off") return undefined;

    try {
      const text = event.prompt ?? "";
      const truncated = text.slice(0, MAX_STATE_CHARS);

      // Compute in-context skills from compaction-aware session entries
      let entries: any[] = [];
      try {
        entries = getContextEntries(ctx);
      } catch {
        if (!_sessionWarnFired) {
          _sessionWarnFired = true;
          console.warn("[skill-router] session context unavailable; dedup cannot work this session");
        }
      }
      const inContext = skillsInContext(entries);

      // Check for explicit turn — skip routing
      const explicit = isExplicitTurn(truncated, catalogNameSet);

      let hits: Map<string, number>;
      let toInject: Array<{ name: string; score: number }> = [];
      let kevStatus: "ok" | "failed" | "skipped" = "skipped";
      let kevProbs: Record<string, number> = {};

      if (explicit) {
        hits = new Map();
      } else {
        hits = scorePrompt(text, catalogNames, catalogNameSet);

        // Kev filter: only when rules produced hits
        if (hits.size > 0) {
          const cwd = process.cwd().replace(process.env.HOME ?? "", "~");
          const state = `Working directory: ${cwd}\nUser request:\n${truncated}`;
          const fb = await kevThenRules(hits, catalog, state, inContext, _config);
          toInject = fb.toInject;
          kevStatus = fb.kevStatus;
          kevProbs = fb.probs;
        }
      }

      // Shadow mode: log decision but return nothing
      if (_config.mode === "shadow") {
        try {
          const decision = {
            mode: "shadow" as const,
            kev: kevStatus,
            probs: kevProbs,
            wouldInject: toInject.map((s) => s.name),
            hits: Object.fromEntries(hits),
            inContext: [...inContext],
            explicit,
          };
          pi.appendEntry(DECISION_ENTRY, decision);
        } catch { /* never fail the turn for logging */ }
        return undefined;
      }

      // Inject mode: record decision and inject
      try {
        const decision = {
          mode: "inject" as const,
          kev: kevStatus,
          probs: kevProbs,
          hits: Object.fromEntries(hits),
          inContext: [...inContext],
          injected: toInject.map((s) => s.name),
          explicit,
        };
        pi.appendEntry(DECISION_ENTRY, decision);
      } catch { /* never fail the turn for logging */ }

      // Build injection messages
      const result: any = {};

      if (toInject.length > 0) {
        const bodies = toInject
          .map((s) => catalog.get(s.name))
          .filter((e): e is CatalogEntry => !!e)
          .map(formatSkillMessage);
        if (bodies.length > 0) {
          result.message = {
            customType: CUSTOM_TYPE,
            content: bodies.join("\n\n"),
            display: false,
          };
        }
      }

      // Transform system prompt: replace skill block with names-only list
      if (event.systemPrompt) {
        result.systemPrompt = replaceSkillsBlock(event.systemPrompt, namesOnlyBlock);
      }

      return Object.keys(result).length > 0 ? result : undefined;
    } catch (err) {
      // Never break a turn
      try { console.error("[skill-router] before_agent_start error:", err); } catch { /* */ }
      return undefined;
    }
  });

  // Subagent routing + commit gate
  pi.on("tool_call", async (event, ctx) => {
    // ── Subagent routing ──────────────────────────────────────────
    if (event.toolName === "subagent" && _config.mode !== "off") {
      try {
        await routeSubagentSkills(event.input, catalog, catalogNames, catalogNameSet, pi, ctx);
      } catch {
        // Never block a subagent call — leave input untouched on any error
      }
      return; // subagent calls never reach the commit gate
    }

    // ── Commit gate ──────────────────────────────────────────────
    try {
      let cmd: string | null = null;
      if (event.toolName === "bash") {
        cmd = (event.input as { command?: string }).command ?? "";
      } else if (event.toolName === "edit" || event.toolName === "write") {
        const fused = (event.input as any)?.then_run?.command;
        if (typeof fused === "string") cmd = fused;
      }
      if (!cmd || !isRealGitCommit(cmd)) return;

      // If catalog has no git-commit skill, the gate can never be satisfied; allow the command.
      if (!catalog.has("git-commit")) return;

      // Check if git-commit is in context from any source.
      // If session introspection throws, fail closed with a clear reason.
      let inContext: Set<string>;
      try {
        const entries = getContextEntries(ctx);
        inContext = skillsInContext(entries);
      } catch (err) {
        return {
          block: true,
          reason: `[skill-router] Cannot verify git-commit gate (${err instanceof Error ? err.message : String(err)}). Load skill:git-commit before committing.`,
        };
      }
      if (inContext.has("git-commit")) return;

      // Load the git-commit skill body into the block reason so the agent
      // can apply it and retry.  The marker MUST be at position 0 so that
      // skillsInContext (startsWith check) recognises the toolResult on retry.
      const gcEntry = catalog.get("git-commit");
      const skillBlock = gcEntry ? "\n\n" + formatSkillMessage(gcEntry) : "";

      return {
        block: true,
        reason: `${GIT_COMMIT_SKILL_MARKER}\nApply the skill instructions below and retry.${skillBlock}`,
      };
    } catch (err) {
      // Unexpected error in command parsing — fail closed
      return {
        block: true,
        reason: `[skill-router] Commit gate error: ${err instanceof Error ? err.message : String(err)}. Load skill:git-commit before committing.`,
      };
    }
  });
}

// ── Exports for testing ─────────────────────────────────────────────
export {
  parseFrontmatter,
  buildNameRegex,
  isExplicitTurn,
  scorePrompt,
  selectSkills,
  selectSkillsWithKev,
  skillsInContext,
  formatSkillMessage,
  buildNamesOnlyList,
  replaceSkillsBlock,
  getContextEntries,
  loadCatalog,
  loadConfig,
  expandTilde,
  queryKev,
  queryKevWithState,
  kevThenRules,
  routeSubagentSkills,
  stripShellNonCommands,
  isRealGitCommit,

  isCodingTask,
  detectLanguages,
  resolveRepoRoot,
  ENFORCER,
  LANGUAGE_MAP,
  _setConfig,
  _getConfig,
  validateDeciderUrl,
  MAX_STATE_CHARS,
  SCORE_NAMED,
  SCORE_ENFORCER,
  CUSTOM_TYPE,
  DECISION_ENTRY,
  GIT_COMMIT_SKILL_MARKER,
};
export type { CatalogEntry, RouterConfig, DeciderConfig, KevResult, KevFallbackResult };
