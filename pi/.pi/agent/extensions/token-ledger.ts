import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { appendFileSync, mkdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const LEDGER_DIR = join(process.env.HOME ?? "", ".local", "share", "pi");
const LEDGER_PATH = join(LEDGER_DIR, "token-ledger.jsonl");

interface LedgerEntry {
  ts: string;
  taskId: string;
  sessionId: string;
  event: "turn" | "dispatch" | "claim" | "close";
  children?: number;
  tokens?: { input?: number; output?: number };
}

function summarize(entries: LedgerEntry[]) {
  let turns = 0;
  let dispatches = 0;
  let inputTokens = 0;
  let outputTokens = 0;

  for (const e of entries) {
    if (e.event === "turn") turns++;
    if (e.event === "dispatch") dispatches++;
    if (e.tokens) {
      inputTokens += e.tokens.input ?? 0;
      outputTokens += e.tokens.output ?? 0;
    }
  }

  return { turns, dispatches, inputTokens, outputTokens };
}

export default function (pi: ExtensionAPI): void {
  let currentTaskId: string | null = null;
  let sessionId = "";
  let pendingTokens: { input?: number; output?: number } | null = null;

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
    if (event.toolName === "dispatch" || event.toolName === "workflow") {
      if (currentTaskId) {
        const tasks = (event.input as any)?.tasks;
        append({
          ts: new Date().toISOString(),
          taskId: currentTaskId,
          sessionId,
          event: "dispatch",
          children: Array.isArray(tasks) ? tasks.length : 1,
        });
      }
      return;
    }

    if (event.toolName !== "bash") return;
    const cmd = (event.input as any)?.command ?? "";

    // Detect bd update --claim <taskId>
    const claimMatch = cmd.match(/bd\s+update\s+(\S+)\s+--claim/);
    if (claimMatch) {
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

  // Capture token usage from message_update if available
  pi.on("message_update", async (event) => {
    const usage = (event as any).usage;
    if (usage) {
      pendingTokens = {
        input: usage.input_tokens ?? usage.inputTokens,
        output: usage.output_tokens ?? usage.outputTokens,
      };
    }
  });

  pi.on("agent_settled", async () => {
    if (!currentTaskId) return;
    const entry: LedgerEntry = {
      ts: new Date().toISOString(),
      taskId: currentTaskId,
      sessionId,
      event: "turn",
    };
    if (pendingTokens) {
      entry.tokens = pendingTokens;
      pendingTokens = null;
    }
    append(entry);
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
        const matched = entries.filter((e) => e.taskId.startsWith(epicId));
        const s = summarize(matched);
        ctx.ui.notify(
          `Epic ${epicId}: ${s.turns} turns, ${s.dispatches} dispatches, ~${s.inputTokens} in / ~${s.outputTokens} out tokens`,
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
          `Task ${flags}: ${s.turns} turns, ${s.dispatches} dispatches, ~${s.inputTokens} in / ~${s.outputTokens} out tokens`,
          "info",
        );
        return;
      }

      // No arg: session summary
      const sessionEntries = entries.filter((e) => e.sessionId === sessionId);
      const s = summarize(sessionEntries);
      ctx.ui.notify(
        `Session: ${s.turns} turns, ${s.dispatches} dispatches, ~${s.inputTokens} in / ~${s.outputTokens} out tokens`,
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
            `${e.ts.slice(5, 16)} [${e.event.padEnd(8)}] ${e.taskId}${e.tokens ? ` (${e.tokens.input ?? 0}→${e.tokens.output ?? 0})` : ""}`,
        )
        .join("\n");
      ctx.ui.notify(formatted, "info");
    },
  });
}
