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
      const raw = readFileSync(LEDGER_PATH, "utf-8").trim();
      if (!raw) return [];
      return raw.split("\n").map((line) => JSON.parse(line));
    } catch {
      return [];
    }
  }

  pi.on("session_start", async (_event, _ctx) => {
    sessionId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  });

  pi.on("tool_call", async (event) => {
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
      currentTaskId = claimMatch[1];
      append({
        ts: new Date().toISOString(),
        taskId: currentTaskId,
        sessionId,
        event: "claim",
      });
      return;
    }

    // Detect bd close <taskId>
    const closeMatch = cmd.match(/bd\s+close\s+(\S+)/);
    if (closeMatch) {
      const closedId = closeMatch[1];
      if (!TASK_ID_RE.test(closedId)) return;
      append({
        ts: new Date().toISOString(),
        taskId: closedId,
        sessionId,
        event: "close",
      });
      if (closedId === currentTaskId) {
        currentTaskId = null;
      }
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

  // The logged decision is pi's, before later handlers; pi-cache-optimizer only
  // flips stop->warm for zero-priced models whose warmCost is 0, so dollar
  // totals stay exact. Never override the decision.
  pi.on("cache_warming_decision", (event) => {
    const e = event as any;
    if (e.action === "warm") {
      append({
        event: "warm",
        cost: num(e.warmCost),
        taskId: currentTaskId,
        sessionId,
        ts: new Date().toISOString(),
      });
    }
    return undefined;
  });

  pi.on("agent_settled", async () => {
    const { cost, ...tokens } = acc;
    acc = fresh();
    append({
      ts: new Date().toISOString(),
      taskId: currentTaskId,
      sessionId,
      event: "turn",
      tokens,
      cost,
    });
  });

  pi.registerCommand("cost", {
    description: "Show token cost per task or epic. Usage: /cost [task-id] | /cost --epic <id>",
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
