// knowledge-base — Pi extension
// Deterministic keyword matching against ~/llm-wiki/INDEX.md.
// Instead of injecting the full INDEX every turn, parses entries into a lookup
// table and injects only entries whose keywords match the user's prompt.
// Falls back to SYSTEM.md instruction for oblique references.
// Commits wiki changes on agent_settled.

import type {
  ExtensionAPI,
  SessionStartEvent,
  BeforeAgentStartEvent,
  SessionCompactEvent,
  AgentSettledEvent,
} from "@earendil-works/pi-coding-agent";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const WIKI_PATH = join(process.env.HOME ?? "", "llm-wiki");
const INDEX_PATH = join(WIKI_PATH, "INDEX.md");

// ── Entry parsing ─────────────────────────────────────────────────────────

interface WikiEntry {
  path: string;
  alias: string | null;
  description: string;
  keywords: string[];
  section: string;
}

// Stop words to exclude from keyword matching
const STOP_WORDS = new Set([
  "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
  "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
  "has", "have", "had", "do", "does", "did", "will", "would", "could",
  "should", "may", "might", "can", "this", "that", "these", "those",
  "it", "its", "no", "not", "new", "via", "into", "also", "just",
]);

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOP_WORDS.has(w));
}

function parseIndex(raw: string): WikiEntry[] {
  const entries: WikiEntry[] = [];
  let currentSection = "";

  for (const line of raw.split("\n")) {
    // Track section headings
    const headingMatch = line.match(/^#{1,3}\s+(.+)/);
    if (headingMatch) {
      currentSection = headingMatch[1].trim();
      continue;
    }

    // Parse wiki link entries: - [[path|Alias]] — description
    const entryMatch = line.match(
      /^-\s+\[\[([^\]|]+)(?:\|([^\]]+))?\]\]\s*(?:—\s*(.*))?$/
    );
    if (!entryMatch) continue;

    const path = entryMatch[1].trim();
    const alias = entryMatch[2]?.trim() ?? null;
    const description = entryMatch[3]?.trim() ?? "";

    // Build keywords from: path segments, alias, description, section
    const keywordSources = [
      ...path.split("/"),
      ...(alias ? [alias] : []),
      description,
      currentSection,
    ].join(" ");

    const keywords = [...new Set(tokenize(keywordSources))];

    entries.push({ path, alias, description, keywords, section: currentSection });
  }

  return entries;
}

// ── Fuzzy matching (bigram Dice coefficient) ──────────────────────────────

function bigrams(word: string): Set<string> {
  const bg = new Set<string>();
  for (let i = 0; i < word.length - 1; i++) {
    bg.add(word.slice(i, i + 2));
  }
  return bg;
}

function diceCoefficient(a: string, b: string): number {
  if (a === b) return 1;
  if (a.length < 2 || b.length < 2) return 0;
  const bgA = bigrams(a);
  const bgB = bigrams(b);
  let intersection = 0;
  for (const bg of bgA) {
    if (bgB.has(bg)) intersection++;
  }
  return (2 * intersection) / (bgA.size + bgB.size);
}

const FUZZY_THRESHOLD = 0.65;

// ── Matching ──────────────────────────────────────────────────────────────

const MIN_PROMPT_WORDS = 3;
const MAX_RESULTS = 8;

function matchEntries(prompt: string, entries: WikiEntry[]): WikiEntry[] {
  const promptTokens = tokenize(prompt);
  if (promptTokens.length < MIN_PROMPT_WORDS) return [];

  // Score each entry by number of keyword hits
  const scored: Array<{ entry: WikiEntry; score: number }> = [];

  for (const entry of entries) {
    let score = 0;
    for (const pt of promptTokens) {
      for (const kw of entry.keywords) {
        // Exact match always counts
        if (kw === pt) {
          score++;
          break;
        }
        // Substring containment for tokens ≥5 chars
        if (pt.length >= 5 && (kw.includes(pt) || pt.includes(kw))) {
          score++;
          break;
        }
        // Fuzzy match for tokens ≥4 chars via bigram similarity
        if (pt.length >= 4 && kw.length >= 4 && diceCoefficient(pt, kw) >= FUZZY_THRESHOLD) {
          score += 0.75; // Slightly lower weight than exact matches
          break;
        }
      }
    }
    if (score > 0) scored.push({ entry, score });
  }

  // Sort by score descending, take top N
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, MAX_RESULTS).map((s) => s.entry);
}

function formatMatches(matches: WikiEntry[]): string {
  if (matches.length === 0) return "";

  const lines: string[] = [
    "## Knowledge Base (~/llm-wiki)",
    "",
    "Relevant notes for this context (use `read` to load full content):",
    "",
  ];

  // Group by section for readability
  const bySection = new Map<string, WikiEntry[]>();
  for (const entry of matches) {
    const section = entry.section || "Other";
    if (!bySection.has(section)) bySection.set(section, []);
    bySection.get(section)!.push(entry);
  }

  for (const [section, entries] of bySection) {
    if (bySection.size > 1) lines.push(`**${section}**`);
    for (const e of entries) {
      const label = e.alias ?? e.path.split("/").pop() ?? e.path;
      lines.push(`- [[${e.path}|${label}]]${e.description ? ` — ${e.description}` : ""}`);
    }
    if (bySection.size > 1) lines.push("");
  }

  return lines.join("\n");
}

// ── Injection state (pure helpers) ────────────────────────────────────────

export const CUSTOM_TYPE = "knowledge-base";

export interface SessionEntryLike {
  type: string;
  id?: string;
  customType?: string;
  details?: { keys?: string[] } | null;
  firstKeptEntryId?: string;
}

/**
 * Rebuild the set of injected entry keys from session entries (oldest first).
 * A compaction entry drops keys from messages before its firstKeptEntryId,
 * since those messages are no longer in context and may be re-injected.
 */
export function recoverInjectedKeys(sessionEntries: SessionEntryLike[]): Set<string> {
  const seen: Array<string | undefined> = [];
  let kept: Array<{ id?: string; keys: string[] }> = [];
  for (const e of sessionEntries) {
    if (e.type === "compaction") {
      const idx = seen.indexOf(e.firstKeptEntryId);
      kept = idx >= 0 ? kept.filter((k) => seen.indexOf(k.id) >= idx) : [];
      continue;
    }
    seen.push(e.id);
    if (e.type === "custom_message" && e.customType === CUSTOM_TYPE) {
      kept.push({ id: e.id, keys: e.details?.keys ?? [] });
    }
  }
  return new Set(kept.flatMap((k) => k.keys));
}

export interface InjectionResult {
  message: { customType: string; content: string; display: boolean; details: { keys: string[] } };
}

/** Build the before_agent_start result; never includes systemPrompt. Mutates `injected`. */
export function buildInjection(
  prompt: string,
  entries: WikiEntry[],
  injected: Set<string>,
): InjectionResult | undefined {
  const fresh = matchEntries(prompt, entries).filter((m) => !injected.has(m.path));
  if (fresh.length === 0) return undefined;
  for (const m of fresh) injected.add(m.path);
  return {
    message: {
      customType: CUSTOM_TYPE,
      content: formatMatches(fresh),
      display: false,
      details: { keys: fresh.map((m) => m.path) },
    },
  };
}

export { parseIndex };

// ── Extension ─────────────────────────────────────────────────────────────

export default function (pi: ExtensionAPI): void {
  let entries: WikiEntry[] = [];
  let injected = new Set<string>();

  function reload(): void {
    try {
      const raw = readFileSync(INDEX_PATH, "utf8").trim();
      entries = parseIndex(raw);
    } catch {
      entries = [];
    }
  }

  function recover(ctx: { sessionManager: { getEntries(): unknown[] } }): void {
    injected = recoverInjectedKeys(ctx.sessionManager.getEntries() as SessionEntryLike[]);
  }

  reload();

  pi.on("session_start", async (_event: SessionStartEvent, ctx) => {
    reload();
    recover(ctx);
  });

  pi.on(
    "before_agent_start",
    async (event: BeforeAgentStartEvent, _ctx): Promise<InjectionResult | void> => {
      // Matches go in as an appended custom message, never systemPrompt: a changing
      // system prompt invalidates the provider prompt cache on most turns. Each entry
      // is injected at most once per session so the earlier prefix never changes.
      // Behavioural change: because systemPrompt is no longer returned, other
      // extensions' sections (Ponytail's always-on text) are no longer stripped.
      return buildInjection(event.prompt, entries, injected);
    },
  );

  // No session_before_compact handler on purpose. In pi's compact(), a `compaction`
  // result from an extension REPLACES the generated summary (summary,
  // firstKeptEntryId and tokensBefore are taken from it and the default summarizer
  // is skipped), so the old handler dropped everything since the last compaction.

  pi.on("session_compact", async (_event: SessionCompactEvent, ctx) => {
    reload();
    // Messages before firstKeptEntryId are gone from context: allow re-injection.
    recover(ctx);
  });

  pi.on("agent_settled", async (_event: AgentSettledEvent, _ctx) => {
    try {
      const status = await pi.exec("git", ["status", "--porcelain"], {
        cwd: WIKI_PATH,
        timeout: 5000,
      });
      if (!status.stdout?.trim()) return;
      const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
      await pi.exec(
        "sh",
        ["-c", `git add -A && git commit -m 'auto-sync: session idle ${timestamp}' && git push`],
        { cwd: WIKI_PATH, timeout: 15000 },
      );
    } catch {
      // wiki not a git repo or push failed — non-fatal
    }
  });
}
