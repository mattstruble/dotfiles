# SoL-Pi Action Fusion — Validation Guide

## Is Action Fusion Active?

Check the config:

```bash
cat pi/.pi/agent/sol-pi.json
# Expected: "actionFusion": true
```

The coder agent prompt (agents/coder.md) instructs the model to use `then_run: { command: "<cmd>" }` on edit/write calls when the follow-up command is predictable (tests, type-check, lint).

## How It Works

Action Fusion collapses an edit + verification into a single conversational turn:

| Without Fusion | With Fusion |
|---|---|
| Turn 1: `edit` file | Turn 1: `edit` file + `then_run: { command: "npm test" }` |
| Turn 2: `bash` run tests | *(fused into turn 1)* |
| 2 turns, 2× input replay | 1 turn, 1× input replay |

Each saved turn avoids replaying the full conversation prefix, which at typical context sizes (50–100k tokens) is the dominant cost driver.

## Metrics to Track

### 1. Fused Calls in Audit Log

The audit extension (`extensions/audit.ts`) logs fused commands with a distinct marker:

```bash
# Count fused calls
grep -c "fused via then_run" ~/.local/share/pi/audit.jsonl

# View fused calls with context
grep "fused via then_run" ~/.local/share/pi/audit.jsonl | python3 -m json.tool --no-ensure-ascii | head -40
```

A nonzero count confirms the model is actually using Action Fusion. Zero means the model hasn't adopted the pattern yet — this is expected early on since `then_run` is a prompt-level hint, not enforced.

### 2. Turns Per Task (Token Ledger)

The token ledger at `~/.local/share/pi/token-ledger.jsonl` records `claim`, `dispatch`, `close`, and `turn` events per task.

```bash
# Turns per task (lower = better)
python3 -c "
import json, sys
from collections import defaultdict

tasks = defaultdict(lambda: {'turns': 0, 'dispatches': 0})
for line in open('$HOME/.local/share/pi/token-ledger.jsonl'):
    e = json.loads(line)
    tid = e['taskId']
    if e['event'] == 'turn':
        tasks[tid]['turns'] += 1
    elif e['event'] == 'dispatch':
        tasks[tid]['dispatches'] += e.get('children', 0)

for tid, d in sorted(tasks.items()):
    if d['turns'] > 0:
        print(f'{tid:30s}  turns={d[\"turns\"]:3d}  dispatches={d[\"dispatches\"]:2d}')
"
```

### 3. Cache Hit Rate (Session Footer)

Claude Code displays context window usage in the session footer (via `extensions/statusline.ts`). The Anthropic API returns `cache_read_input_tokens` and `cache_creation_input_tokens` in each response's `usage` block.

To check cache efficiency at the API level:

```bash
# If you have access to the Claude API usage dashboard:
# cache_read_input_tokens / (cache_read_input_tokens + input_tokens) = cache hit rate
# Target: >70% for multi-turn sessions
```

Action Fusion improves cache hit rate indirectly: fewer turns means fewer requests, which means less cache churn and higher hit rates on the requests that remain.

## Before/After Comparison Template

Record these values for a set of comparable tasks (e.g., 5 coder subtasks):

| Metric | Before Fusion | After Fusion | Delta |
|---|---|---|---|
| Avg turns per coder subtask | __ | __ | __% |
| Fused calls per session | 0 | __ | n/a |
| Avg context at task close | __k | __k | __% |
| Subjective: fewer "just running tests" turns? | n/a | yes/no | — |

### Collecting baseline

The token ledger already has pre-fusion data from earlier sessions. Tasks before the `dotfiles-tga.*` series used the old config. Compare:

```bash
# Pre-fusion tasks (before sol-pi.json existed)
grep -v "tga" ~/.local/share/pi/token-ledger.jsonl | grep '"turn"' | wc -l

# Post-fusion tasks
grep "tga" ~/.local/share/pi/token-ledger.jsonl | grep '"turn"' | wc -l
```

## Expected Effects

1. **Fewer turns per task** — each fused edit+test saves one round trip
2. **Lower input tokens per task** — each saved turn avoids replaying the full conversation context
3. **Higher cache hit rate** — fewer total requests means less cache key churn
4. **Cost reduction** — dominated by input token savings; estimated 10–30% for edit-heavy tasks

## Limitations

- Action Fusion is a **prompt-level hint**, not a tool-level enforcement. The model may not always use it.
- The `then_run` field is only meaningful on `edit` and `write` calls. Read-heavy tasks won't benefit.
- The audit log only captures fused calls if the model actually passes `then_run`. No fusion ≠ broken config.
- Token ledger doesn't record raw token counts — only turn/dispatch/close events. For token-level analysis, use the Anthropic dashboard or API response headers.
