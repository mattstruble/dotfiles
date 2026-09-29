# skill-router

Pi extension that injects the skills a turn needs instead of hoping the agent loads them. It replaces
`skill-enforcer.ts`: same trigger patterns and commit check, plus skill injection, a names-only skill list, and an
optional model filter (the local [Kev decision server](../../../../README.md#kev-decision-server)).

## What happens on each user turn

1. **Explicit turns are left alone.** If the prompt starts with a catalog skill name, contains `/skill:<name>`, a
   `<skill` block, or `SKILL.md`, nothing is routed.
2. **Rules score the first 2,000 characters of the prompt.** A skill named in the prompt (`git-pr`, `/git-pr`,
   `git pr`) scores 1.0. A match on one of the trigger patterns (the `ENFORCER` list in the source: commit, PR,
   implement/refactor, tests, docker, helm, nix, python, API design, code review) scores 0.75. Only skills in the
   catalog count.
3. **The decider filters the hits.** When there are hits, the router asks the decider one yes/no question per hit
   ("Would a careful coding agent load the `<skill>` skill before handling this request?", with the skill's
   description cut to 400 characters). Hits with a probability of at least `decider.threshold` are kept, ordered by
   probability, and cut to `maxSkillsPerTurn`.
4. **Without a decider, the rules decide.** On a timeout, connection error, non-200 reply or malformed answer, the
   turn uses the rule scores instead (hits scoring at least 0.5, same cap) and warns once per Pi process.
5. **Skills already in context are skipped.** The router looks at what is in the model's context right now: its own
   earlier injections, `SKILL.md` files the agent read, and explicit `/skill` expansions. After compaction drops an
   injection, the skill can be injected again on the next matching turn.
6. **The rest is injected.** Skill bodies go in one hidden message (`customType: "skill-router"`, Pi's `/skill`
   block format), and the system prompt's skill list is replaced by a names-only list with the path to read any
   skill by hand.
7. **A decision entry is recorded** in the session file (`customType: "skill-router-decision"`): mode, decider
   status (`ok`, `failed`, `skipped`), probabilities, rule hits, skills already in context, skills injected, and
   whether the turn was explicit. No prompt text is stored.

**Subagents.** On a `dispatch` tool call each task is routed independently.

- **Coding task** — `tools` includes `write`/`edit`, or `worktree: true` / `allowTreeMutation: true`.
- **Language detection** — from file names/extensions in the task text and from top-level marker files of the `Repo root:` directory (or the working directory). The language map covers Python, Nix, Docker, Helm, Odin, Godot (+ shaders), Fennel/LÖVE, and LÖVE 2D.
- **Precedence** — detected language skills and `software-design` are injected first without the Kev filter, then the usual rules + Kev picks are appended; duplicates and already-present skills are dropped; the total is capped at `maxSkillsPerTask`.
- **Shadow and off** — shadow mode logs decisions (with `wouldInject`) without mutating tasks; off mode does nothing.

**Commit check.** A `bash` command, or an `edit`/`write` with a `then_run` command, is checked for a real
`git commit` invocation. The check strips heredoc bodies (`<<EOF … EOF`, `<<'EOF'`, `<<-EOF`), ANSI-C `$'…'`
strings, single- and double-quoted string contents, and `#` comments, then looks for `git` at a command position
(start of line, after `; && || | (` `$(`, or after leading `VAR=value` assignments or `sudo`/`env`/`command`/`exec`)
followed by optional global options and the subcommand `commit`. When the gate blocks, the block reason includes the
full git-commit SKILL.md body behind the `[skill-router] git-commit skill loaded for this commit:` marker; the skill
arrives in the blocked call's error result so the agent can apply it and retry without a separate read.

## Configuration

`~/.pi/agent/skill-router.json`, linked by Home Manager to `pi/.pi/agent/skill-router.json` in this repo, so edits
take effect without a rebuild. The file is read once when the extension loads: restart Pi after changing it. A
missing file means all defaults. Invalid JSON means all defaults; an invalid field falls back to its default, and
one warning lists every invalid field.

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `mode` | `"inject"`, `"shadow"`, `"off"` | `"inject"` | `inject` routes and injects. `shadow` records decisions (with `wouldInject`) but changes nothing the model sees. `off` does no routing; the commit check still runs. |
| `decider.url` | string | `"http://127.0.0.1:8008"` | Decider base URL (`POST /v1/systemone`). Plain `http://` is allowed only for `127.0.0.1`, `::1` and `localhost`; `https://` to another host is allowed with a one-time warning that prompts leave the machine. Anything else disables the decider, so routing uses the rules alone. |
| `decider.model` | string | `"kev-latest"` | Model name sent with each request. The Kev server answers to `kev-latest` whichever checkpoint it runs. |
| `decider.timeoutMs` | number > 0 | `1500` | Per-request timeout. On timeout that turn falls back to the rules. |
| `decider.threshold` | number, 0 to 1 | `0.30` | Minimum probability to keep a hit. Tuned for Kev-0.8B on the replay labels (it removed a quarter of the wrong injections without losing a right one); not yet tuned for Kev-4B. |
| `decider.apiKeyEnv` | string or `null` | `null` | Name of an environment variable holding a bearer token for a hosted decider. The token is never read from this file; the router warns once if the variable is empty. |
| `catalog` | string | `"~/.pi/agent/skill-profiles/all"` | Directory of `<name>/SKILL.md` skills to route over, independent of the per-directory skill profiles. `~` is expanded. |
| `maxSkillsPerTurn` | number > 0 | `2` | Most skills injected per user turn and per dispatched task (non-coding). |
| `maxSkillsPerTask` | number > 0 | `3` | Most skills injected per dispatched coding task (language + software-design + Kev picks). |

What leaves the Pi process: the working directory and the first 2,000 characters of each prompt and dispatched task,
sent only to `decider.url`.

Which Kev checkpoint answers is set per host by `services.kev-server.model` in the nix-darwin config
(`jaredpalmer/kev-0.8b` by default, `jaredpalmer/kev-4b` on MacStruble); the router config does not change.

## Checking what it did

Decisions for the newest session:

```bash
f=$(ls -t ~/.pi/agent/sessions/*/*.jsonl | head -1)
grep -o '"customType":"skill-router[a-z-]*"' "$f" | sort | uniq -c   # injections and decision entries
grep -o '"kev":"[a-z]*"' "$f" | sort | uniq -c                       # decider status per routed turn
```

## Tests

```bash
npx tsx --test pi/.pi/agent/extensions/skill-router.test.ts \
  pi/.pi/agent/extensions/skill-router-parity.test.ts
npx tsx --test pi/.pi/agent/extensions/skill-router-kev-parity.test.ts   # needs Kev on :8008
```

The parity tests compare against the replay harness in `~/.local/share/pi-decision-eval` and skip when its local
data is absent; no session text is stored in this repo.
