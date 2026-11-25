// Headless permission engine: runs the real pi-permission-system gate pipeline
// (ToolCallGatePipeline.evaluate) against a config file. No rule matching lives
// here; decisions come entirely from the package.
import { copyFileSync, mkdirSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const AGENT_NPM = join(process.env.HOME ?? "", ".pi/agent/npm/node_modules");
const PKG = process.env.PERMISSION_PKG_DIR ?? join(AGENT_NPM, "@gotgenes/pi-permission-system");
const JITI = process.env.PERMISSION_JITI ?? join(AGENT_NPM, "jiti/lib/jiti.mjs");
const STUBS = join(dirname(fileURLToPath(import.meta.url)), "stubs");

/**
 * @param {string} configPath permission config JSON to evaluate
 * @param {{cwd?: string, allowIssues?: boolean}} [opts] allowIssues: evaluate even when the package reports config issues
 * @returns {Promise<{decide(toolName: string, input: object): Promise<{decision: 'allow'|'ask'|'deny', rule: string|null, reason: string|null}>}>}
 */
export async function createEngine(configPath, { cwd = process.cwd(), allowIssues = false } = {}) {
  const agentDir = mkdtempSync(join(tmpdir(), "permreplay-agent-"));
  mkdirSync(join(agentDir, "extensions/pi-permission-system"), { recursive: true });
  copyFileSync(configPath, join(agentDir, "extensions/pi-permission-system/config.json"));
  const setEnv = () => { process.env.PERMREPLAY_AGENT_DIR = agentDir; };
  setEnv();

  // Fresh jiti instance per engine so module state is never shared between configs.
  const { createJiti } = await import(pathToFileURL(JITI).href);
  const jiti = createJiti(import.meta.url, {
    moduleCache: false,
    fsCache: false,
    alias: {
      "@earendil-works/pi-coding-agent": join(STUBS, "pi-coding-agent.mjs"),
      "@earendil-works/pi-tui": join(STUBS, "pi-tui.mjs"),
    },
  });
  const load = (rel) => jiti.import(`${PKG}/${rel}`);
  const { PermissionManager } = await load("src/policy/permission-manager.ts");
  const { ConfigStore } = await load("src/config/config-store.ts");
  const { PermissionResolver } = await load("src/policy/permission-resolver.ts");
  const { SessionRules } = await load("src/session/session-rules.ts");
  const { PermissionSession } = await load("src/session/permission-session.ts");
  const { ToolCallGatePipeline } = await load("src/handlers/gates/tool-call-gate-pipeline.ts");
  const { GateRunner } = await load("src/handlers/gates/runner.ts");
  const { DenyingAuthorizer } = await load("src/authority/denying-authorizer.ts");
  const { PURE_READER_CORE } = await load("src/access-intent/bash/command-effects.ts");
  const { WRAPPER_COMMAND_NAMES } = await load("src/access-intent/bash/wrapper-analysis.ts");
  const { isYoloModeEnabled } = await load("src/config/extension-config.ts");
  const { computeExtensionPaths } = await load("src/config/extension-paths.ts");
  const { pathFlavorForPlatform } = await load("src/path/path-flavor.ts");

  const flavor = pathFlavorForPlatform(process.platform);
  const sessionRules = new SessionRules();
  const trace = [];
  let escalations = 0;
  const pm = new PermissionManager({ agentDir, flavor, isYoloEnabled: () => isYoloModeEnabled(configStore.current()) });
  const configStore = new ConfigStore({
    agentDir,
    policyPaths: pm,
    logger: { debug() {}, review() {}, warn() {} },
    coreCommandWords: PURE_READER_CORE,
    wrapperCommandWords: WRAPPER_COMMAND_NAMES,
  });
  const inner = new PermissionResolver(pm, sessionRules);
  const resolver = {
    resolve(i) {
      const r = inner.resolve(i);
      trace.push({ gate: i.surface, state: r.state, source: r.source, pattern: r.matchedPattern ?? null });
      return r;
    },
  };
  const noop = { start() {}, stop() {} };
  const session = new PermissionSession(
    computeExtensionPaths(agentDir, "/nonexistent"), noop, pm, sessionRules, configStore,
    { activate() {}, deactivate() {} }, flavor,
  );
  const ctx = { cwd, hasUI: false };
  session.refreshConfig(ctx, true);
  session.resetForNewSession(ctx, true);
  const escalator = { async escalate() { escalations++; return new DenyingAuthorizer().authorize(); } };
  const runner = new GateRunner(
    resolver, sessionRules, escalator,
    { writeReviewLog() {}, emitDecision() {} },
    () => isYoloModeEnabled(configStore.current()),
  );
  const pipeline = new ToolCallGatePipeline(resolver, session);
  // The package silently falls back to defaults (ask on everything) when the
  // config is unreadable or invalid; refuse to evaluate rather than report that.
  const issues = [...configStore.getConfigIssues(), ...inner.getPolicyIssues()]
    .map((i) => i.split(join(agentDir, "extensions/pi-permission-system/config.json")).join(configPath));
  if (issues.length > 0 && !allowIssues) {
    throw new Error(`invalid permission config ${configPath}:\n  ${issues.join("\n  ")}`);
  }

  let n = 0;
  return {
    agentDir, issues,
    async decide(toolName, input) {
      setEnv();
      trace.length = 0;
      escalations = 0;
      const out = await pipeline.evaluate(
        { toolName, agentName: null, input, toolCallId: `replay-${n++}`, cwd }, runner);
      const decision = out.action === "allow" ? "allow" : escalations > 0 ? "ask" : "deny";
      const want = decision === "allow" ? null : decision;
      const hit = want ? [...trace].reverse().find((t) => t.state === want) : null;
      const rule = hit ? `${hit.gate}=${hit.state}(${hit.source}${hit.pattern ? ` ${hit.pattern}` : ""})` : null;
      return { decision, rule, reason: out.reason ?? null };
    },
  };
}
