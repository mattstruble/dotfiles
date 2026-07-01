// conductor — OpenCode plugin
// Async subagent lifecycle management: spawn, prompt, status, result, cancel.

function extractText(msg) {
  if (typeof msg.content === "string") return msg.content;
  if (Array.isArray(msg.parts)) {
    return msg.parts
      .filter((p) => p.type === "text")
      .map((p) => p.text)
      .join("");
  }
  return "";
}

export const ConductorPlugin = async ({ client }) => {
  return {
    tool: {
      conductor_spawn: {
        description:
          "Spawn a new subagent session with a given agent type and prompt. Returns the session ID for tracking.",
        parameters: {
          type: "object",
          properties: {
            agent: {
              type: "string",
              description: "Agent type to use for the session (e.g. 'coder', 'explorer')",
            },
            prompt: {
              type: "string",
              description: "Initial prompt to send to the subagent",
            },
            description: {
              type: "string",
              description: "Human-readable title for the session",
            },
          },
          required: ["agent", "prompt", "description"],
        },
        execute: async ({ agent, prompt, description }) => {
          const session = await client.session.create({
            body: { title: description },
          });
          const id = session.id;
          try {
            await client.session.promptAsync({
              path: { id },
              body: { parts: [{ type: "text", text: prompt }], agent },
            });
          } catch (e) {
            // promptAsync failed — abort the orphaned session before returning error
            try { await client.session.abort({ path: { id } }); } catch {}
            return JSON.stringify({ error: e.message });
          }
          return JSON.stringify({ session_id: id });
        },
      },

      conductor_prompt: {
        description:
          "Send a follow-up prompt to an existing subagent session. Returns an error if the session is not found or not active.",
        parameters: {
          type: "object",
          properties: {
            session_id: {
              type: "string",
              description: "ID of the session to send the prompt to",
            },
            prompt: {
              type: "string",
              description: "Follow-up prompt to send",
            },
          },
          required: ["session_id", "prompt"],
        },
        execute: async ({ session_id, prompt }) => {
          const statuses = await client.session.status();
          const entry = statuses.find((s) => s.id === session_id);
          if (!entry || entry.status === "idle" || entry.status === "error") {
            return JSON.stringify({
              error: "session not found or not active",
              session_id,
            });
          }
          await client.session.promptAsync({
            path: { id: session_id },
            body: { parts: [{ type: "text", text: prompt }] },
          });
          return JSON.stringify({ ok: true });
        },
      },

      conductor_batch_status: {
        description:
          "Get status and recent activity for multiple subagent sessions at once.",
        parameters: {
          type: "object",
          properties: {
            session_ids: {
              type: "array",
              items: { type: "string" },
              description: "List of session IDs to check",
            },
          },
          required: ["session_ids"],
        },
        execute: async ({ session_ids }) => {
          const statuses = await client.session.status();
          const statusMap = Object.fromEntries(statuses.map((s) => [s.id, s.status]));

          const settled = await Promise.allSettled(
            session_ids.map(async (id) => {
              const status = statusMap[id];
              if (status === undefined) {
                return { id, status: "error", error: "not found" };
              }

              const messages = await client.session.messages({ path: { id } });
              const now = Date.now();

              const timestamps = messages
                .map((m) => m.created_at ?? m.timestamp ?? null)
                .filter((t) => t !== null)
                .map((t) => new Date(t).getTime())
                .filter((t) => !isNaN(t));

              const elapsed_ms =
                timestamps.length > 0
                  ? now - timestamps.reduce((a, b) => Math.min(a, b))
                  : null;
              const last_activity_ms =
                timestamps.length > 0
                  ? now - timestamps.reduce((a, b) => Math.max(a, b))
                  : null;

              const assistantMsgs = messages.filter((m) => m.role === "assistant");
              const lastAssistant = assistantMsgs[assistantMsgs.length - 1];
              const lastText = lastAssistant ? extractText(lastAssistant) : "";
              const last_message = lastText.slice(0, 200);

              const tool_calls = messages.filter(
                (m) =>
                  m.role === "tool" ||
                  (Array.isArray(m.parts) && m.parts.some((p) => p.type === "tool-call"))
              ).length;

              return { id, status, elapsed_ms, last_activity_ms, last_message, tool_calls };
            })
          );

          const results = settled.map((r, i) =>
            r.status === "fulfilled"
              ? r.value
              : { id: session_ids[i], status: "error", error: r.reason?.message ?? String(r.reason) }
          );

          return JSON.stringify(results);
        },
      },

      conductor_result: {
        description:
          "Retrieve the full content of the last assistant message from a subagent session.",
        parameters: {
          type: "object",
          properties: {
            session_id: {
              type: "string",
              description: "ID of the session to retrieve the result from",
            },
          },
          required: ["session_id"],
        },
        execute: async ({ session_id }) => {
          let messages;
          try {
            messages = await client.session.messages({ path: { id: session_id } });
          } catch (e) {
            return JSON.stringify({ session_id, content: "", error: e.message });
          }
          const assistantMsgs = messages.filter((m) => m.role === "assistant");
          const last = assistantMsgs[assistantMsgs.length - 1];
          if (!last) {
            return JSON.stringify({
              session_id,
              content: "",
              error: "no assistant message",
            });
          }
          return JSON.stringify({ session_id, content: extractText(last) });
        },
      },

      conductor_cancel: {
        description: "Abort a running subagent session.",
        parameters: {
          type: "object",
          properties: {
            session_id: {
              type: "string",
              description: "ID of the session to cancel",
            },
          },
          required: ["session_id"],
        },
        execute: async ({ session_id }) => {
          try {
            await client.session.abort({ path: { id: session_id } });
          } catch (e) {
            return JSON.stringify({ error: e.message, session_id });
          }
          return JSON.stringify({ cancelled: true, session_id });
        },
      },
    },
  };
};
