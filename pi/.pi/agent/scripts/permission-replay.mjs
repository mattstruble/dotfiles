#!/usr/bin/env node
// Replay real permission prompts from the review log against two policy configs
// and run assertion fixtures against the new one. Decisions come from the real
// package gate pipeline via permission-engine.mjs; nothing here matches rules.
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createEngine } from "./permission-engine.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_LOG = join(homedir(), ".pi/agent/extensions/pi-permission-system/logs/pi-permission-system-permission-review.jsonl");
const DEFAULT_FIXTURES = join(HERE, "permission-fixtures.json");
const DEFAULT_CWD = join(homedir(), "dotfiles");
const SAMPLE_SIZE = 30;
const SEED = 1;
const PATH_TOOLS = new Set(["read", "grep", "find", "ls"]);
const WRITE_TOOLS = new Set(["edit", "write"]);

function parseArgs(argv) {
  const pos = [];
  const opts = { log: DEFAULT_LOG, fixtures: DEFAULT_FIXTURES, cwd: DEFAULT_CWD };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--log") opts.log = argv[++i];
    else if (a === "--fixtures") opts.fixtures = argv[++i];
    else if (a === "--cwd") opts.cwd = argv[++i];
    else pos.push(a);
  }
  if (pos.length !== 2) {
    console.error("usage: permission-replay.mjs <old.json> <new.json> [--log <path>] [--fixtures <path>] [--cwd <dir>]");
    process.exitCode = 2;
    throw new Error("expected exactly two config paths");
  }
  return { oldConfig: resolve(pos[0]), newConfig: resolve(pos[1]), ...opts };
}

function fullCommand(entry) {
  const m = typeof entry.message === "string" ? /\(full command: '([\s\S]*)'\)\. Allow/.exec(entry.message) : null;
  return m ? m[1] : entry.command;
}

/** Turn a log entry into {tool, input, label} or {skip: class}. */
export function toReplayable(entry, cwd) {
  const tool = entry.toolName;
  if (tool === "bash") {
    const command = fullCommand(entry);
    if (!command) return { skip: "bash: no command recorded" };
    return { tool, input: { command }, label: command };
  }
  if (entry.path) return { tool, input: { path: entry.path }, label: entry.path };
  if (WRITE_TOOLS.has(tool)) {
    const path = join(cwd, "replay-placeholder.txt");
    return { tool, input: { path }, label: `(placeholder path) ${path}` };
  }
  if (PATH_TOOLS.has(tool)) return { skip: `${tool}: external-directory entry without a path` };
  return { skip: `${tool ?? "unknown"}: no recorded input to replay` };
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function seededSample(items, n, seed) {
  const arr = items.slice();
  const rnd = mulberry32(seed);
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr.slice(0, n);
}

const oneLine = (s, n = 200) => {
  const t = String(s).replace(/\s+/g, " ");
  return t.length > n ? `${t.slice(0, n)}…` : t;
};

function loadEntries(logPath) {
  if (!existsSync(logPath)) throw new Error(`review log not found: ${logPath}`);
  const out = [];
  for (const line of readFileSync(logPath, "utf8").split("\n")) {
    if (!line.trim()) continue;
    try {
      const e = JSON.parse(line);
      if (e.event === "permission_request.waiting") out.push(e);
    } catch { /* skip malformed line */ }
  }
  return out;
}

function matchesExpect(expect, decision) {
  return Array.isArray(expect) ? expect.includes(decision) : expect === decision;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const oldEngine = await createEngine(args.oldConfig, { cwd: args.cwd });
  const newEngine = await createEngine(args.newConfig, { cwd: args.cwd });

  const entries = loadEntries(args.log);
  const skipped = new Map();
  const replayable = [];
  for (const e of entries) {
    const r = toReplayable(e, args.cwd);
    if (r.skip) skipped.set(r.skip, (skipped.get(r.skip) ?? 0) + 1);
    else replayable.push(r);
  }

  const cache = new Map();
  const decideCached = async (engine, tag, r) => {
    const key = `${tag}\0${r.tool}\0${JSON.stringify(r.input)}`;
    if (!cache.has(key)) cache.set(key, await engine.decide(r.tool, r.input));
    return cache.get(key);
  };

  let oldAsk = 0;
  let newAsk = 0;
  const newDeny = [];
  const stillAsk = [];
  for (const r of replayable) {
    const o = await decideCached(oldEngine, "old", r);
    const n = await decideCached(newEngine, "new", r);
    if (o.decision === "ask") oldAsk++;
    if (n.decision === "ask") {
      newAsk++;
      stillAsk.push({ r, n });
    }
    if (n.decision === "deny") newDeny.push({ r, o, n });
  }

  const total = replayable.length;
  const pct = (a, b) => (b === 0 ? "n/a" : `${((a / b) * 100).toFixed(1)}%`);
  console.log(`log: ${args.log}`);
  console.log(`old: ${args.oldConfig}`);
  console.log(`new: ${args.newConfig}`);
  console.log(`cwd: ${args.cwd}`);
  console.log("");
  console.log(`waiting entries in log: ${entries.length}`);
  console.log(`replayable entries (denominator): ${total}`);
  console.log(`old ask count: ${oldAsk}`);
  console.log(`new ask count: ${newAsk}`);
  console.log(`new/old ask: ${pct(newAsk, oldAsk)}`);
  console.log(`calibration rate (replayable entries the old config asks on): ${pct(oldAsk, total)} (${oldAsk}/${total})`);

  console.log("");
  console.log(`entries that deny under the new config: ${newDeny.length}`);
  for (const { r, o, n } of newDeny) {
    console.log(`  [${r.tool}] ${oneLine(r.label)}  (old: ${o.decision}; ${n.rule ?? n.reason ?? ""})`);
  }

  const sample = seededSample(stillAsk, SAMPLE_SIZE, SEED);
  console.log("");
  console.log(`sample of entries that still ask under the new config (seed ${SEED}, ${sample.length} of ${stillAsk.length}):`);
  for (const { r, n } of sample) console.log(`  [${r.tool}] ${oneLine(r.label)}  (${n.rule ?? ""})`);

  console.log("");
  console.log("skipped entry classes:");
  if (skipped.size === 0) console.log("  (none)");
  for (const [cls, count] of [...skipped].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))) console.log(`  ${count}  ${cls}`);

  // Fixtures against the new config.
  console.log("");
  let failures = 0;
  if (!existsSync(args.fixtures)) {
    console.log(`fixtures: file not found: ${args.fixtures}`);
    failures++;
  } else {
    const fixtures = JSON.parse(readFileSync(args.fixtures, "utf8"));
    console.log(`fixtures: ${fixtures.length} cases from ${args.fixtures}`);
    // A fixture may set its own cwd; engines for other cwds are created lazily.
    const engines = new Map([[args.cwd, newEngine]]);
    const engineFor = async (cwd) => {
      if (!engines.has(cwd)) engines.set(cwd, await createEngine(args.newConfig, { cwd }));
      return engines.get(cwd);
    };
    for (const f of fixtures) {
      const got = await (await engineFor(f.cwd ? resolve(f.cwd) : args.cwd)).decide(f.tool, f.input);
      if (!matchesExpect(f.expect, got.decision)) {
        failures++;
        console.log(`  FAIL [${f.tool}] ${oneLine(JSON.stringify(f.input))}: expected ${JSON.stringify(f.expect)}, got ${got.decision}${got.rule ? ` (${got.rule})` : ""}${f.note ? ` - ${f.note}` : ""}`);
      }
    }
    console.log(`fixtures: ${fixtures.length - failures} passed, ${failures} failed`);
  }
  // exitCode, not process.exit: exiting right after many writes can drop buffered pipe output.
  process.exitCode = failures > 0 ? 1 : 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((err) => { console.error(`permission-replay: ${err?.message ?? err}`); process.exitCode = 2; });
}
