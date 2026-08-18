# Pi Agent Profiles

The Pi coding agent uses a profile system defined in `pi/.pi/agent/extensions/agent-profiles.ts` to switch between three specialized modes of operation.

## Profiles

### Planner
Decomposes work into beads tasks by exploring the codebase (read-only) and creating epics, tasks, and dependencies. It runs a Q&A loop to clarify requirements, stress-tests the plan via a plan-critic, and stops at user approval — it never implements code directly.

### Orchestrator
Executes a beads task graph by dispatching coder and reviewer subagents in parallel; it never writes or edits files itself. It manages the full review loop (correctness, failure-path, readability, and security reviewers), retries failed tasks up to two times, and closes tasks once all reviewers sign off.

### Builder
Implements changes directly using the full tool set (read, write, edit, bash, grep, etc.). Intended for straightforward, single-session work where a full planning and orchestration workflow is unnecessary.

## Tab-Cycle Behavior

Pressing **Tab** in the Pi agent UI cycles through profiles in order: `planner → orchestrator → builder → planner → …`. The active profile name and resolved model are shown in the status bar. Profiles can also be set explicitly with `/profile <name>` or triggered for immediate epic execution with `/orchestrate <epic-id>`.
