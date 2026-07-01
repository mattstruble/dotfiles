// conductor — OpenCode plugin
// Background watchdog: monitors subtask sessions for inactivity and auto-aborts frozen ones.
// No tools registered — works silently alongside the native `task` tool.

export const ConductorPlugin = async ({ client }) => {
  const POLL_INTERVAL = 30000; // Check every 30 seconds
  const INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000; // 3 minutes of no activity after last tool completed


  const interval = setInterval(async () => {
    try {
      // Get status of all sessions
      const statusResponse = await client.session.status();
      const statusMap = statusResponse.data ?? {};

      // Find busy sessions
      const busySessionIds = Object.entries(statusMap)
        .filter(([_, s]) => s.type === "busy")
        .map(([id]) => id);

      if (busySessionIds.length > 0) {

      for (const sessionId of busySessionIds) {
        // Only monitor subtask sessions (those with a parentID)
        let session;
        try {
          const sessionResponse = await client.session.get({ path: { id: sessionId } });
          session = sessionResponse.data;
        } catch {
          continue; // Can't fetch session, skip
        }
        if (!session?.parentID) continue; // Not a subtask, skip

        // Get messages to check tool activity
        let messages;
        try {
          const msgResponse = await client.session.messages({ path: { id: sessionId } });
          messages = msgResponse.data ?? [];
        } catch {
          continue; // Can't fetch messages, skip
        }

        // Find all tool parts across all messages
        const allToolParts = messages.flatMap((m) =>
          (m.parts ?? []).filter((p) => p.type === "tool")
        );

        // If a tool is currently running (pending or running), session is active — skip
        const lastTool = allToolParts[allToolParts.length - 1];
        if (
          lastTool &&
          (lastTool.state?.status === "pending" || lastTool.state?.status === "running")
        ) {
          continue;
        }

        // Collect all activity timestamps (message creation + tool start/end times)
        const timestamps = [];
        for (const msg of messages) {
          if (msg.info?.time?.created) timestamps.push(msg.info.time.created);
          for (const part of msg.parts ?? []) {
            if (part.type === "tool" && part.state?.time?.end) timestamps.push(part.state.time.end);
            if (part.type === "tool" && part.state?.time?.start) timestamps.push(part.state.time.start);
          }
        }

        if (timestamps.length === 0) continue; // No data yet, skip

        // Timestamps may be epoch seconds (10 digits) or ms (13 digits)
        const toMs = (t) => (t < 1e12 ? t * 1000 : t);
        const lastActivityMs = Math.max(...timestamps.map(toMs));
        const inactiveMs = Date.now() - lastActivityMs;

        if (inactiveMs > INACTIVITY_TIMEOUT_MS) {
          // Session is stale — abort it
          try {
            await client.session.abort({ path: { id: sessionId } });
          } catch {
            // Abort failed — nothing we can do
          }
        }
      }
    } catch {
      // Watchdog errors must never crash the plugin
    }
  }, POLL_INTERVAL);

  return {
    dispose: () => {
      clearInterval(interval);
    },
  };
};
