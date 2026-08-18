import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const timeoutMs = parseInt(process.env.PI_CONDUCTOR_TIMEOUT_MS || "120000", 10);
  let lastActivity = Date.now();
  let agentRunning = false;
  let toolInFlight = false;
  let modelResponding = false;
  let watchdogInterval: ReturnType<typeof setInterval> | null = null;
  let sessionCtx: any = null;

  const touch = () => {
    lastActivity = Date.now();
  };

  pi.on("session_start", async (_event, ctx) => {
    // Clear any leaked interval from a prior session_start
    if (watchdogInterval) clearInterval(watchdogInterval);
    sessionCtx = ctx;
    watchdogInterval = setInterval(() => {
      // Skip abort if a tool is actively running (may be legitimately long)
      if (agentRunning && !toolInFlight && !modelResponding && Date.now() - lastActivity > timeoutMs && sessionCtx) {
        sessionCtx.ui.notify(`Agent stalled for ${timeoutMs / 1000}s — aborting`, "warning");
        sessionCtx.abort();
      }
    }, 5000);
  });

  pi.on("session_shutdown", async () => {
    if (watchdogInterval) clearInterval(watchdogInterval);
    watchdogInterval = null;
  });

  pi.on("agent_start", async () => {
    agentRunning = true;
    touch();
  });

  pi.on("turn_start", async () => {
    modelResponding = true;
    touch();
  });

  pi.on("turn_end", async () => {
    modelResponding = false;
    touch();
  });

  pi.on("agent_end", async () => {
    agentRunning = false;
    toolInFlight = false;
    modelResponding = false;
    touch();
  });

  pi.on("agent_settled", async () => {
    agentRunning = false;
    toolInFlight = false;
    touch();
  });

  pi.on("tool_call", async () => {
    toolInFlight = true;
    touch();
  });

  pi.on("tool_result", async () => {
    toolInFlight = false;
    touch();
  });

  pi.on("message_update", async () => {
    touch();
  });
}
