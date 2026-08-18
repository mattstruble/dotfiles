export const meta = {
  name: 'beads-review',
  description:
    'Dispatch correctness and failure-path reviewers for completed coder tasks. Creates review subtasks, dispatches reviewer subagents in parallel, reports findings.',
};

const { spawnSync } = require('node:child_process');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

// ── Helpers ───────────────────────────────────────────────────────────────

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

function loadAgentPrompt(name) {
  const paths = [
    join(cwd, '.pi/agent/agents', `${name}.md`),
    join(process.env.HOME, '.pi/agent/agents', `${name}.md`),
  ];
  for (const p of paths) {
    try {
      const raw = readFileSync(p, 'utf8');
      return raw.replace(/^---[\s\S]*?---\s*/, '').trim();
    } catch {}
  }
  return null;
}

async function safeAgent(prompt, opts) {
  try {
    const value = await agent(prompt, opts);
    return { ok: true, value };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

// ── Config ────────────────────────────────────────────────────────────────

// args.tasks: array of task IDs to review
// args.diff: optional — provide diff directly instead of computing from git
// args.worktreePath: optional — path to worktree with changes
const taskIds = Array.isArray(args?.tasks) ? args.tasks.filter(Boolean) : [];

if (taskIds.length === 0) {
  log('no tasks provided — pass { tasks: ["task-id", ...] }');
  return { ok: false, error: 'no tasks to review' };
}

// ── Load reviewer system prompts ──────────────────────────────────────────

const correctnessPrompt = loadAgentPrompt('correctness-reviewer');
const failurePathPrompt = loadAgentPrompt('failure-path-reviewer');

if (!correctnessPrompt || !failurePathPrompt) {
  log('ERROR: reviewer agent prompts not found');
  return { ok: false, error: 'correctness-reviewer.md or failure-path-reviewer.md not found' };
}

// ── Review each task ──────────────────────────────────────────────────────

phase('review');

async function reviewTask(taskId) {
  log(`[${taskId}] starting review…`);

  // Get task context
  let taskContext;
  try {
    taskContext = run('bd', ['show', taskId]);
  } catch (err) {
    return { taskId, ok: false, error: `bd show failed: ${err.message}` };
  }

  // Get the diff for this task (from recent commits or worktree)
  let diff = args?.diff ?? '';
  if (!diff) {
    try {
      // Try to get diff from the task's commits (look for the cherry-pick commit)
      diff = run('git', ['log', '--oneline', '-5', '--format=%H %s'])
        .split('\n')
        .filter((l) => l.includes(taskId))
        .map((l) => l.split(' ')[0])
        .map((hash) => {
          try { return run('git', ['diff', `${hash}^..${hash}`]); } catch { return ''; }
        })
        .join('\n');
    } catch {}
    if (!diff) {
      try { diff = run('git', ['diff', 'HEAD~1..HEAD']); } catch { diff = '(diff unavailable)'; }
    }
  }

  // Create review subtasks
  let correctnessReviewId = null;
  let failurePathReviewId = null;

  try {
    const crOutput = run('bd', [
      'create',
      `--title=correctness review — ${taskId}`,
      `--parent=${taskId}`,
      '--type=task',
      '--priority=3',
      '--json',
    ]);
    const crParsed = JSON.parse(crOutput);
    correctnessReviewId = crParsed.id ?? crParsed.issueId;
    log(`[${taskId}] created correctness review: ${correctnessReviewId}`);
  } catch (err) {
    log(`[${taskId}] failed to create correctness review subtask: ${err.message}`);
  }

  try {
    const fpOutput = run('bd', [
      'create',
      `--title=failure-path review — ${taskId}`,
      `--parent=${taskId}`,
      '--type=task',
      '--priority=3',
      '--json',
    ]);
    const fpParsed = JSON.parse(fpOutput);
    failurePathReviewId = fpParsed.id ?? fpParsed.issueId;
    log(`[${taskId}] created failure-path review: ${failurePathReviewId}`);
  } catch (err) {
    log(`[${taskId}] failed to create failure-path review subtask: ${err.message}`);
  }

  // Build review request
  const reviewRequest = `## Review Request

**Diff source:** git diff (inline)
**Plan/spec:** none (use bd show context below)
**Review focus:** {FOCUS}
**Prior findings to verify:** initial review

## Task Context
${taskContext}

## Diff
\`\`\`diff
${diff.slice(0, 15000)}
\`\`\`

## Beads Review Lifecycle
**Review subtask ID:** {REVIEW_ID}
**Parent task ID:** ${taskId}
**Repo root path:** ${cwd}`;

  // Dispatch both reviewers in parallel
  const reviews = await parallel([
    () =>
      safeAgent(
        reviewRequest
          .replace('{FOCUS}', 'correctness')
          .replace('{REVIEW_ID}', correctnessReviewId ?? 'none'),
        {
          label: `correctness-review:${taskId}`,
          model: args?.model ?? 'amazon-bedrock/us.anthropic.claude-sonnet-4-6',
          tools: ['read', 'bash', 'grep', 'find', 'ls'],
          systemPrompt: correctnessPrompt,
          maxTurns: 12,
        },
      ),
    () =>
      safeAgent(
        reviewRequest
          .replace('{FOCUS}', 'failure-path')
          .replace('{REVIEW_ID}', failurePathReviewId ?? 'none'),
        {
          label: `failure-path-review:${taskId}`,
          model: args?.model ?? 'amazon-bedrock/us.anthropic.claude-sonnet-4-6',
          tools: ['read', 'bash', 'grep', 'find', 'ls'],
          systemPrompt: failurePathPrompt,
          maxTurns: 12,
        },
      ),
  ]);

  const [correctness, failurePath] = reviews;
  const lgtm =
    (correctness.ok && (correctness.value ?? '').includes('LGTM')) &&
    (failurePath.ok && (failurePath.value ?? '').includes('LGTM'));

  log(`[${taskId}] correctness: ${correctness.ok ? 'done' : 'failed'}, failure-path: ${failurePath.ok ? 'done' : 'failed'}, LGTM: ${lgtm}`);

  return {
    taskId,
    ok: true,
    lgtm,
    correctness: {
      reviewId: correctnessReviewId,
      ok: correctness.ok,
      lgtm: correctness.ok && (correctness.value ?? '').includes('LGTM'),
      findings: correctness.ok ? correctness.value : correctness.error,
    },
    failurePath: {
      reviewId: failurePathReviewId,
      ok: failurePath.ok,
      lgtm: failurePath.ok && (failurePath.value ?? '').includes('LGTM'),
      findings: failurePath.ok ? failurePath.value : failurePath.error,
    },
  };
}

// Dispatch all reviews in parallel
const results = await parallel(taskIds.map((id) => () => reviewTask(id)));

// ── Summary ───────────────────────────────────────────────────────────────

phase('summary');

const allLgtm = results.filter((r) => r.ok && r.lgtm);
const withFindings = results.filter((r) => r.ok && !r.lgtm);
const failed = results.filter((r) => !r.ok);

for (const r of allLgtm) log(`✓ ${r.taskId}: LGTM`);
for (const r of withFindings) log(`⚠ ${r.taskId}: has findings`);
for (const r of failed) log(`✗ ${r.taskId}: ${r.error}`);

return {
  reviewed: taskIds.length,
  lgtm: allLgtm.length,
  withFindings: withFindings.length,
  failed: failed.length,
  tasks: results,
};
