export const meta = {
  name: 'plan-critique',
  description:
    'Dispatch the plan-critic agent to review the current beads task graph. Runs up to 3 rounds of critique until convergence ("No further suggestions.") or round limit.',
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
  // Try project-local agents first, then global
  const paths = [
    join(cwd, '.pi/agent/agents', `${name}.md`),
    join(process.env.HOME, '.pi/agent/agents', `${name}.md`),
  ];
  for (const p of paths) {
    try {
      const raw = readFileSync(p, 'utf8');
      // Strip YAML frontmatter
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

const MAX_ROUNDS = args?.maxRounds ?? 3;
const epicId = args?.epic ?? null;
const focus = args?.focus ?? 'full';

// ── Load critic system prompt ─────────────────────────────────────────────

const criticSystemPrompt = loadAgentPrompt('plan-critic');
if (!criticSystemPrompt) {
  log('ERROR: plan-critic.md agent not found');
  return { ok: false, error: 'plan-critic.md not found in agents/' };
}

// ── Critique loop ─────────────────────────────────────────────────────────

phase('critique');

let round = 1;
let priorAddressed = 'initial';
const allSuggestions = [];

while (round <= MAX_ROUNDS) {
  log(`round ${round}/${MAX_ROUNDS}…`);

  // Build the critique request prompt
  const critiquePrompt = `## Critique Request

**Project directory:** ${cwd}
**Epic or root task:** ${epicId ?? 'all open tasks'}
**Critique focus:** ${focus}
**Round:** ${round}
**Prior suggestions addressed:** ${priorAddressed}`;

  const result = await safeAgent(critiquePrompt, {
    label: `plan-critic:round-${round}`,
    model: args?.model ?? 'bedrock/us.anthropic.claude-sonnet-4-6-v1',
    tools: ['read', 'bash', 'grep', 'find', 'ls'],
    systemPrompt: criticSystemPrompt,
    maxTurns: 15,
  });

  if (!result.ok) {
    log(`critic failed in round ${round}: ${result.error}`);
    return { ok: false, round, error: result.error, suggestions: allSuggestions };
  }

  const output = result.value ?? '';
  log(`round ${round} complete (${output.length} chars)`);

  // Check for convergence
  if (output.includes('No further suggestions.')) {
    log('converged — plan is sound');
    return { ok: true, converged: true, rounds: round, suggestions: allSuggestions };
  }

  // Extract suggestions for tracking
  const suggestions = output
    .split(/\*\*Severity:\*\*/)
    .slice(1)
    .map((s) => s.trim().slice(0, 200));
  allSuggestions.push(...suggestions.map((s) => ({ round, summary: s })));

  priorAddressed = suggestions.map((_, i) => `R${round}-${i + 1}`).join(', ');
  round++;
}

log(`reached max rounds (${MAX_ROUNDS}) without convergence`);
return { ok: true, converged: false, rounds: MAX_ROUNDS, suggestions: allSuggestions };
