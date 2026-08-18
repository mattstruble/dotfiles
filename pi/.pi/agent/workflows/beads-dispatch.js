export const meta = {
  name: 'beads-dispatch',
  description:
    'Bridge the beads task graph to subagent dispatch: read bd ready (or accept explicit task IDs), create git worktrees, dispatch coder subagents, cherry-pick results, and close tasks on success.',
};

// ── API assumptions (document for post-install verification) ──────────────
//
// This script runs inside the @nicknisi/pi-workflows vm with these globals:
//   agent(prompt, opts) — spawn a child agent; opts.worktree=true uses pi's
//     managed worktrees (~/.pi/agent/subagent-worktrees/<runId>); opts.tools
//     controls the allowlist; returns the agent's text output or opts.schema
//     parsed data.
//   parallel(thunks) — Promise.all over zero-arg thunks.
//   log(...args)     — captured into result logs.
//   args             — value passed via /wf run beads-dispatch <argsJson>.
//   cwd              — the session working directory (repo root).
//
// Node built-ins are available (full host-process access, same as bash tool).
//
// args shape:
//   { tasks?: string[] }   — explicit task IDs to dispatch
//   (omit tasks or pass []) — use `bd ready` to discover unblocked tasks
//
// Example invocations:
//   /wf run beads-dispatch
//   /wf run beads-dispatch {"tasks":["dotfiles-abc","dotfiles-def"]}
// ─────────────────────────────────────────────────────────────────────────

const { execFileSync, spawnSync } = require('node:child_process');
const { mkdirSync, rmSync, existsSync } = require('node:fs');
const { join } = require('node:path');

// ── Helpers ───────────────────────────────────────────────────────────────

/** Run a command synchronously; return stdout string or throw with stderr. */
function run(cmd, cmdArgs, opts = {}) {
  const result = spawnSync(cmd, cmdArgs, {
    encoding: 'utf8',
    cwd: opts.cwd ?? cwd,
    timeout: opts.timeout ?? 30_000,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const msg = (result.stderr ?? '').trim() || `exit ${result.status}`;
    throw new Error(`${cmd} ${cmdArgs.join(' ')}: ${msg}`);
  }
  return (result.stdout ?? '').trim();
}

/** Parse `bd ready` output into an array of task IDs.
 *  bd ready prints lines like: "○ dotfiles-abc P1 [task] Title"
 *  We extract the ID token (the second whitespace-delimited word).
 *  Beads IDs match: word-chars, hyphens, dots — e.g. dotfiles-abc or dotfiles-d3w.2
 */
function parseBdReady(output) {
  return output
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      // Typical format: "○ dotfiles-abc P1 [task] Title" or "◐ dotfiles-abc …"
      const parts = line.split(/\s+/);
      return parts[1] ?? null;
    })
    // Beads IDs always contain a hyphen (e.g. dotfiles-abc, dotfiles-d3w.2).
    .filter((id) => id && /^[a-z][a-z0-9]*-[a-z0-9]+/.test(id));
}

/** Wrap agent() so a failure returns { ok: false, error } instead of throwing. */
async function safeAgent(prompt, opts) {
  try {
    const value = await agent(prompt, opts);
    return { ok: true, value };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

// ── Session ID ────────────────────────────────────────────────────────────

const sessionId = `pi-${Date.now()}`;

// ── Discover tasks ────────────────────────────────────────────────────────

phase('discover tasks');

const explicitTasks = Array.isArray(args?.tasks) ? args.tasks.filter(Boolean) : [];
let taskIds;

if (explicitTasks.length > 0) {
  taskIds = explicitTasks;
  log(`using ${taskIds.length} explicit task(s): ${taskIds.join(', ')}`);
} else {
  log('running bd ready to discover unblocked tasks…');
  let readyOutput;
  try {
    readyOutput = run('bd', ['ready'], { cwd });
  } catch (err) {
    throw new Error(`bd ready failed: ${err.message}`);
  }
  taskIds = parseBdReady(readyOutput);
  log(`bd ready found ${taskIds.length} task(s): ${taskIds.join(', ')}`);
}

if (taskIds.length === 0) {
  log('no tasks to dispatch');
  return { dispatched: 0, succeeded: 0, failed: 0, tasks: [] };
}

// ── Dispatch one task ─────────────────────────────────────────────────────

async function dispatchTask(taskId) {
  const worktreePath = join('/tmp/opencode-wt', sessionId, taskId);
  const branch = `opencode/${taskId}`;
  let worktreeCreated = false;
  let baseCommit;

  try {
    // 1. Record base commit before creating the worktree.
    baseCommit = run('git', ['rev-parse', 'HEAD']);

    // 2. Create worktree on a fresh branch.
    log(`[${taskId}] creating worktree at ${worktreePath}`);
    mkdirSync(worktreePath, { recursive: true });
    run('git', ['worktree', 'add', worktreePath, '-b', branch]);
    worktreeCreated = true;

    // 3. Get task context from beads.
    log(`[${taskId}] fetching task context…`);
    const taskContext = run('bd', ['show', taskId]);

    // 4. Build the coder prompt.
    const coderSystemPrompt = `You are the Coder agent. You receive a fully self-contained task prompt and execute it to completion.

## Phase 1: Orientation

Before writing any code:

1. **Claim your task.** Run \`bd -C ${cwd} update ${taskId} --claim\`.
2. **Read task state.** Run \`bd -C ${cwd} show ${taskId}\` to read the task description, acceptance criteria, and any existing subtasks. If subtasks already exist and some are closed (crash recovery), skip those — resume from the first open subtask.
3. **Read the relevant files** listed in your task prompt.
4. **Create implementation subtasks** under your task with file scope hints:
   \`\`\`
   bd -C ${cwd} create "description — path/to/file.ext" --parent ${taskId} --json
   \`\`\`
   Close each subtask as you complete it: \`bd -C ${cwd} close <subtask-id>\`.

## Phase 2: Implementation

1. **Write code.** Follow the conventions and patterns present in the codebase.
2. **Close subtasks** as each implementation chunk completes.
3. **Run tests and checks.** Fix any failures before proceeding.
4. **Verify your changes** against the success criteria in your task prompt.

## Phase 3: Completion Report

Close the parent task: \`bd -C ${cwd} close ${taskId} --reason "Implementation complete"\`.

Return a structured report with: Task, Changes Made, Verification, Commits, Notes.

## Critical Rules

- **ALWAYS operate within the worktree path: ${worktreePath}**
- **ALWAYS claim your task first** before doing any other work.
- **ALWAYS use beads subtasks** to track implementation progress.
- **ALWAYS commit your changes** in the worktree before reporting completion.
- **On re-spawn (crash recovery):** Run \`bd -C ${cwd} show ${taskId}\` to read task state. Skip closed subtasks. Resume from the first open subtask.`;

    const coderPrompt = `## Task Assignment

**Task ID**: ${taskId}
**Repo root**: ${cwd}
**Worktree path**: ${worktreePath}

## Task Context

${taskContext}

## Instructions

Implement this task in the worktree at \`${worktreePath}\`. All file operations must target that path. Commit your changes in the worktree when done. Report completion with the commit hash(es).`;

    // 5. Dispatch the coder subagent into the worktree.
    log(`[${taskId}] dispatching coder subagent…`);
    const result = await safeAgent(coderPrompt, {
      label: `coder:${taskId}`,
      model: 'amazon-bedrock/us.anthropic.claude-sonnet-4-6',
      tools: ['read', 'write', 'edit', 'bash', 'grep', 'glob', 'fetch'],
      systemPrompt: coderSystemPrompt,
      // NOTE: worktree:true uses pi's managed worktrees (~/.pi/agent/subagent-worktrees/<runId>)
      // and returns a .patch file. We use our own worktree (already created above) so the
      // coder's bash tool runs in the right directory. The cwd for the child is set to
      // worktreePath via the prompt; the agent uses bash to operate there.
      // ponytail: not using worktree:true because we need a specific path for cherry-pick;
      // upgrade to worktree:true + git apply if pi adds cwd-override for worktree runs.
    });

    if (!result.ok) {
      log(`[${taskId}] subagent failed: ${result.error}`);
      return { taskId, ok: false, error: result.error, worktreePath };
    }

    log(`[${taskId}] subagent completed`);

    // 6. Cherry-pick commits from the worktree branch back to the current branch.
    const worktreeHead = run('git', ['rev-parse', `${branch}`]);
    if (worktreeHead === baseCommit) {
      log(`[${taskId}] no commits in worktree — nothing to cherry-pick`);
    } else {
      log(`[${taskId}] cherry-picking ${baseCommit.slice(0, 8)}..${worktreeHead.slice(0, 8)}`);
      // Cherry-pick the range of commits the coder made in the worktree.
      run('git', ['cherry-pick', '--no-commit', `${baseCommit}..${branch}`]);
      // Commit the cherry-picked changes with an attribution message.
      run('git', [
        'commit',
        '--allow-empty',
        '-m',
        `feat(${taskId}): apply coder output from worktree\n\nCherry-picked from ${branch} (${worktreeHead.slice(0, 8)})`,
      ]);
      log(`[${taskId}] cherry-pick committed`);
    }

    // 7. Close the task in beads.
    try {
      run('bd', ['close', taskId, '--reason', 'Implemented by coder subagent via beads-dispatch']);
      log(`[${taskId}] task closed`);
    } catch (err) {
      // Non-fatal: task may already be closed by the coder itself.
      log(`[${taskId}] bd close warning (may already be closed): ${err.message}`);
    }

    return { taskId, ok: true, output: result.value, worktreePath };
  } catch (err) {
    log(`[${taskId}] error: ${err.message}`);
    return { taskId, ok: false, error: err.message, worktreePath };
  } finally {
    // 8. Clean up the worktree regardless of outcome.
    if (worktreeCreated) {
      try {
        run('git', ['worktree', 'remove', '--force', worktreePath]);
        log(`[${taskId}] worktree removed`);
      } catch (err) {
        log(`[${taskId}] worktree cleanup warning: ${err.message}`);
        // Best-effort rmSync fallback if git worktree remove fails.
        try {
          rmSync(worktreePath, { recursive: true, force: true });
        } catch {
          // ignore
        }
      }
    }
  }
}

// ── Dispatch all tasks in parallel ───────────────────────────────────────

phase('dispatch');
log(`dispatching ${taskIds.length} task(s) in parallel…`);

const results = await parallel(taskIds.map((id) => () => dispatchTask(id)));

// ── Summary ───────────────────────────────────────────────────────────────

phase('summary');

const succeeded = results.filter((r) => r.ok);
const failed = results.filter((r) => !r.ok);

for (const r of succeeded) log(`✓ ${r.taskId}`);
for (const r of failed) log(`✗ ${r.taskId}: ${r.error}`);

return {
  dispatched: taskIds.length,
  succeeded: succeeded.length,
  failed: failed.length,
  tasks: results.map((r) => ({
    taskId: r.taskId,
    ok: r.ok,
    ...(r.ok ? {} : { error: r.error }),
  })),
};
