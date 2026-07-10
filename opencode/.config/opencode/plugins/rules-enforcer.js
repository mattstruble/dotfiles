// rules-enforcer — OpenCode plugin
// Injects core behavioral rules into every system prompt so they survive compaction.

export const RulesEnforcerPlugin = async () => {
  return {
    "experimental.chat.system.transform": async (_input, output) => {
      output.system.push(`## Core Rules (always active)
- Every sentence carries information. No pleasantries, hedging, preamble, or restating the question.
- No self-narration ("Let me search..."). Execute and present results.
- Ask before diving: when uncertain or a fix fails, ask the user rather than exploring further.
- One clarifying question at a time.
- Minimal changes only. Do not refactor beyond what is asked.`);
    },
  };
};
