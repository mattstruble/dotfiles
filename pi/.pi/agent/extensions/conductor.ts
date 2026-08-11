import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const timeoutMs = parseInt(process.env.PI_CONDUCTOR_TIMEOUT_MS || "120000", 10);
  let lastActivity = Date.now();
  let agentRunning = false;
  let watchdogInterval: ReturnType<typeof setInterval> | null = null;

  const touch = () => {
    lastActivity = Date.now();
  };

  pi.on("session_start", async () => {
    watchdogInterval = setInterval(() => {
      if (agentRunning && Date.now() - lastActivity > timeoutMs) {
        pi.notify(`Agent stalled for ${timeoutMs / 1000}s — aborting`);
        pi.abort();
      }
    }, 5000);
  });

  pi.on("session_shutdown", async () => {
    if (watchdogInterval) clearInterval(watchdogInterval);
  });

  pi.on("agent_start", async () => {
    agentRunning = true;
    touch();
  });

  pi.on("agent_end", async () => {
    agentRunning = false;
    touch();
  });

  pi.on("agent_settled", async () => {
    agentRunning = false;
    touch();
  });

  pi.on("tool_call", async () => {
    touch();
  });

  pi.on("tool_result", async () => {
    touch();
  });

  pi.on("message_update", async () => {
    touch();
  });
}
