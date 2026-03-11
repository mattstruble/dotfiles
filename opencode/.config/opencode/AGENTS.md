# General Philosophy

Envision the ideal abstraction, then take the minimal steps toward it. Do
not over-engineer toward a future that may not arrive. Incremental progress
toward a clean design beats a large rewrite that tries to get everything
right at once.

# Debugging Approach

- *Ask before diving*. When a fix doesn't work or the cause is unclear, stop
  and ask the user before spelunking through library internals or guessing at
  causes. The user likely has context (e.g., known library quirks, prior
  attempts) that can save significant time.
- When hitting uncertainty, default to "ask the human" rather than "gather
  more data via tools." A single clarifying question is cheaper than 10
  speculative tool calls.
- After a failed attempt, ask what the user is *seeing* (visual behavior,
  console output, etc) rather than assuming and exploring further.

# Clarification Before Implementation

- When uncertain about how something is intended to work, always ask
  clarifying questions before implementing.
- Do not assume intent -- if a request is ambiguous about behavior, scope, or
  side effects, confirm with the user first.
- When asking questions, ask a single question at a time. Once you are clear
  on the answer, you may ask follow up or secondary questions.

# Scope Awareness

Prefer minimal changes. Do not refactor beyond what is asked. If a task
touches one function, do not rewrite the module.

# Planning Discipline

- Maintain one explicit plan/checklist.
- Save active plans in `~/.opencode/drafts/*.plan.md`.
- Update plans continuously as scope/order/assumptions change.

# Context7-First Research

Use Context7 docs before general web search.
