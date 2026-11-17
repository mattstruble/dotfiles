import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { appendFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const LEDGER_DIR = join(process.env.HOME ?? "", ".local", "share", "pi");
const LEDGER_PATH = join(LEDGER_DIR, "token-ledger.jsonl");

const TASK_ID_RE = /^[A-Za-z0-9][\w.-]*$/;

interface LedgerEntry {
  ts: string;
  taskId: string | null;
  sessionId: string;
  event: "turn" | "dispatch" | "claim" | "close" | "warm";
  children?: number;
  tokens?: { input?: number; output?: number; cacheRead?: number; cacheWrite?: number };
  cost?: number;
  model?: string;
}

const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);

function summarize(entries: LedgerEntry[]) {
  let turns = 0;
  let dispatches = 0;
  let inputTokens = 0;
  let outputTokens = 0;
  let turnCost = 0;
  let warms = 0;
  let warmCost = 0;

  for (const e of entries) {
    if (e.event === "turn") turns++;
    if (e.event === "dispatch") dispatches++;
    if (e.event === "turn") turnCost += num(e.cost);
    if (e.event === "warm") {
      warms++;
      warmCost += num(e.cost);
    }
    if (e.tokens) {
      inputTokens += e.tokens.input ?? 0;
      outputTokens += e.tokens.output ?? 0;
    }
  }

  return { turns, dispatches, inputTokens, outputTokens, turnCost, warms, warmCost };
}

function fmtSummary(label: string, s: ReturnType<typeof summarize>): string {
  return `${label}: ${s.turns} turns $${s.turnCost.toFixed(2)} · warming ${s.warms}× $${s.warmCost.toFixed(2)} · ${s.dispatches} dispatches`;
}

// Literal task IDs listed after a `bd close`, in order. Scanning stops at the
// first flag, shell operator, redirect, or end of line; non-literal tokens
// (e.g. `$T`, `$(bd`) are skipped without ending the scan.
function closeIds(rest: string): string[] {
  const ids: string[] = [];
  const line = rest.split("\n", 1)[0];
  for (const raw of line.split(/\s+/)) {
    if (!raw) continue;
    if (raw.startsWith("-") || /^[;|&<>)]/.test(raw)) break;
    let tok = raw;
    // Operator glued to the token (`b;`, `b&&`): keep the ID part and stop.
    const op = tok.search(/[;|&<>]/);
    const stop = op >= 0;
    if (stop) {
      // `2>&1`, `2>/dev/null`: a file-descriptor redirect, not an ID.
      if (/^\d+$/.test(tok.slice(0, op)) && /[<>]/.test(tok[op])) break;
      tok = tok.slice(0, op);
    }
    const q = tok.match(/^(["'])(.*)\1$/);
    if (q) tok = q[2];
    if (TASK_ID_RE.test(tok)) ids.push(tok);
    if (stop) break;
  }
  return ids;
}

export default function (pi: ExtensionAPI): void {
  let currentTaskId: string | null = null;
  let sessionId = "";
  const fresh = () => ({ input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0 });
  let acc = fresh();

  mkdirSync(LEDGER_DIR, { recursive: true });

  function append(entry: LedgerEntry): void {
    try {
      appendFileSync(LEDGER_PATH, JSON.stringify(entry) + "\n");
    } catch { /* never crash */ }
  }

  function readLedger(): LedgerEntry[] {
    if (!existsSync(LEDGER_PATH)) return [];
    try {
      const out: LedgerEntry[] = [];
      for (const line of readFileSync(LEDGER_PATH, "utf-8").split("\n")) {
        if (!line.trim()) continue;
        try {
          const parsed = JSON.parse(line);
          if (
            parsed !== null &&
            typeof parsed === "object" &&
            !Array.isArray(parsed) &&
            typeof parsed.ts === "string" &&
            typeof parsed.event === "string"
          ) {
            out.push(parsed);
          }
        } catch { /* skip malformed line */ }
      }
      return out;
    } catch {
      return [];
    }
  }

  function flushTurn(): void {
    const { cost, ...tokens } = acc;
    if (cost === 0 && Object.values(tokens).every((v) => v === 0)) return;
    acc = fresh();
    append({
      ts: new Date().toISOString(),
      taskId: currentTaskId,
      sessionId,
      event: "turn",
      tokens,
      cost,
    });
  }

  // Warms are taken from pi's completed cache_warm usage entries, so skipped or
  // failed refreshes are not counted and the cost is the billed amount.
  const seenWarms = new Set<string>();

  function warmEntries(ctx: any): any[] {
    try {
      const sm = ctx?.sessionManager;
      if (!sm || typeof sm.getEntries !== "function") return [];
      const all = sm.getEntries();
      return Array.isArray(all)
        ? all.filter((e: any) => e?.type === "usage" && e.kind === "cache_warm")
        : [];
    } catch {
      return [];
    }
  }

  function sweepWarms(ctx: any): void {
    for (const entry of warmEntries(ctx)) {
      if (seenWarms.has(entry.id)) continue;
      seenWarms.add(entry.id);
      append({
        ts: new Date().toISOString(),
        taskId: currentTaskId,
        sessionId,
        event: "warm",
        cost: num(entry.usage?.cost?.total),
        model: entry.model,
      });
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    sessionId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    for (const entry of warmEntries(ctx)) seenWarms.add(entry.id);
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName === "subagent" || event.toolName === "workflow") {
      if (currentTaskId) {
        const input = (event.input as any) ?? {};
        // For chains this counts steps, not leaf agents.
        const children = Array.isArray(input.tasks)
          ? input.tasks.length
          : Array.isArray(input.chain)
            ? input.chain.length
            : 1;
        append({
          ts: new Date().toISOString(),
          taskId: currentTaskId,
          sessionId,
          event: "dispatch",
          children,
        });
      }
      return;
    }

    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";

    // Detect bd update --claim <taskId>
    const claimMatch = cmd.match(/bd\s+update\s+(\S+)\s+--claim/);
    if (claimMatch) {
      if (!TASK_ID_RE.test(claimMatch[1])) return;
      sweepWarms(ctx);
      flushTurn();
      currentTaskId = claimMatch[1];
      append({
        ts: new Date().toISOString(),
        taskId: currentTaskId,
        sessionId,
        event: "claim",
      });
      return;
    }

    // Detect bd close <id> [<id> ...]
    for (const m of cmd.matchAll(/bd\s+close(?=\s|$)/g)) {
      let closedCurrent = false;
      for (const closedId of closeIds(cmd.slice(m.index + m[0].length))) {
        if (closedId === currentTaskId) {
          sweepWarms(ctx);
          flushTurn();
          closedCurrent = true;
        }
        append({
          ts: new Date().toISOString(),
          taskId: closedId,
          sessionId,
          event: "close",
        });
      }
      if (closedCurrent) currentTaskId = null;
    }
  });

  pi.on("message_end", (event) => {
    const msg = (event as any).message;
    if (msg?.role !== "assistant" || !msg.usage) return;
    const u = msg.usage;
    acc.input += num(u.input);
    acc.output += num(u.output);
    acc.cacheRead += num(u.cacheRead);
    acc.cacheWrite += num(u.cacheWrite);
    acc.cost += num(u.cost?.total);
  });

  // Never override pi's decision; only sweep completed warms.
  pi.on("cache_warming_decision", (_event, ctx) => {
    sweepWarms(ctx);
    return undefined;
  });

  pi.on("agent_start", async (_event, ctx) => {
    sweepWarms(ctx);
  });

  pi.on("agent_settled", async (_event, ctx) => {
    flushTurn();
    sweepWarms(ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    sweepWarms(ctx);
    flushTurn();
  });

  pi.registerCommand("cost", {
    description: "Show dollar spend (turns and cache warming) per task or epic. Usage: /cost [task-id] | /cost --epic <id>",
    handler: async (args, ctx) => {
      const entries = readLedger();
      const flags = args.trim();

      if (flags.startsWith("--epic")) {
        const epicId = flags.replace("--epic", "").trim();
        if (!epicId) {
          ctx.ui.notify("Usage: /cost --epic <epic-id>", "warning");
          return;
        }
        const matched = entries.filter((e) => e.taskId != null && e.taskId.startsWith(epicId));
        const s = summarize(matched);
        ctx.ui.notify(
          fmtSummary(`Epic ${epicId}`, s),
          "info",
        );
        return;
      }

      if (flags) {
        const matched = entries.filter((e) => e.taskId === flags);
        if (matched.length === 0) {
          ctx.ui.notify(`No ledger entries for task ${flags}`, "info");
          return;
        }
        const s = summarize(matched);
        ctx.ui.notify(
          fmtSummary(`Task ${flags}`, s),
          "info",
        );
        return;
      }

      // No arg: session summary
      const sessionEntries = entries.filter((e) => e.sessionId === sessionId);
      const s = summarize(sessionEntries);
      ctx.ui.notify(
        fmtSummary("Session", s),
        "info",
      );
    },
  });

  pi.registerCommand("ledger", {
    description: "Show recent token ledger entries. Usage: /ledger [count]",
    handler: async (args, ctx) => {
      const entries = readLedger();
      const count = parseInt(args.trim() || "10", 10);
      const recent = entries.slice(-count);
      if (recent.length === 0) {
        ctx.ui.notify("Ledger is empty.", "info");
        return;
      }
      const formatted = recent
        .map(
          (e) =>
            `${e.ts.slice(5, 16)} [${e.event.padEnd(8)}] ${e.taskId ?? "-"}${e.tokens ? ` (${e.tokens.input ?? 0}→${e.tokens.output ?? 0})` : ""}${typeof e.cost === "number" ? ` $${e.cost.toFixed(3)}` : ""}`,
        )
        .join("\n");
      ctx.ui.notify(formatted, "info");
    },
  });
}
