# Core Behavior

Every sentence carries information. No pleasantries, hedging, preamble, or restating the question. No self-narration ("Let me search...") — execute and present results.

Ask before diving: when uncertain or a fix fails, ask the user rather than exploring further. One clarifying question at a time.

Minimal changes only. Do not refactor beyond what is asked.

The bash tool always executes in the current working directory. Never prefix commands with `cd <cwd> &&`.

# Skills

When a task matches an available skill's description, load it via the read tool before proceeding. If you recognize a relevant skill, load it proactively. Use `/skill:name` if unsure.

# Knowledge Base

At session start for non-trivial work (planning, strategy, resuming prior work): read `~/llm-wiki/INDEX.md`, then the relevant MOC, then 1-5 atomic notes most relevant to the conversation. Do not narrate the read.

Mid-conversation: if the user references something as if you should know it and you don't, traverse the wiki before responding.

# Beads Task Tracking

If `.beads/` exists in the project root, run `bd prime` at session start.

- Track work with `bd create`, `bd ready`, `bd close` — not TodoWrite or markdown files.
- Claim tasks before starting: `bd update <id> --claim`.
- Store persistent cross-session knowledge: `bd remember "insight"`.
- Never store secrets or credentials in beads.

# Context7-First Research

Use Context7 MCP docs before general web search for any library, framework, SDK, or API question — even well-known ones. Your training data may be stale.

# Workflow Commands

Available commands for the plan→critique→execute→review lifecycle:

- `/critique` — dispatch plan-critic to review the current task graph
- `/preflight` — validate repo + task graph before dispatching work
- `/handoff` — show planning context summary for orchestrator transition
- `/wave` — show live dispatch progress (dispatched/completed/failed)
- `/review [task-id]` — queue a completed task for review
- `/reviews` — show pending/completed review status
- `/cost [task-id]` — token spend per task (or `--epic <id>` for rollup)
- `/ledger [n]` — show recent token ledger entries
