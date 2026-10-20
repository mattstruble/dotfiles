# skill-router

Pi extension that injects the skills a turn needs instead of hoping the agent loads them. It replaces
`skill-enforcer.ts`: the commit check, keyword triggers read from skill frontmatter, plus skill injection, a names-only skill list, and an
optional model filter (the local [Kev decision server](../../../../README.md#kev-decision-server)).

## What happens on each user turn

1. **Explicit turns are left alone.** If the prompt starts with a catalog skill name, contains `/skill:<name>`, a
   `<skill` block, or `SKILL.md`, nothing is routed.
2. **Rules score the first 2,000 characters of the prompt.** A skill named in the prompt (`git-pr`, `/git-pr`,
   `git pr`) scores 1.0. A match on the skill's `metadata.route-prompt` keywords (read from its SKILL.md
   frontmatter, compiled once at catalog load) scores 0.75. Skills with `disable-model-invocation: true` are manual:
   they are never scored, never sent to the decider, left out of the names-only list and never routed to subagents
   (typing `/skill:<name>` still works through Pi itself). Only skills in the catalog count.
3. **The decider filters the hits.** When there are hits, the router asks the decider one yes/no question per hit
   ("Would a careful coding agent load the `<skill>` skill before handling this request?", with the skill's full
   description). Hits with a probability of at least `decider.threshold` are kept, ordered by
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

**Keyword syntax (`route-prompt`).** Space-separated words, each matched as a whole word, case-insensitive. `*`
inside a word matches any text; `-` matches a hyphen or a space (`git-push` matches `git push` and `git-push`). A
word starting or ending with a non-word character (`.py`) drops the word boundary on that side. A word made only of
`*` and `-`, or an empty spec, is invalid: the skill's keyword signal is disabled and one warning per process lists
the skill. `route-paths` and `route-commands` drive the edit/command gate below.

**Subagents.** On a `subagent` tool call each task text (single `task`, `tasks[]` items, `chain` steps including `parallel` items) is scored independently. Picked skill *names* are merged into the call's top-level `skill` field (existing array/CSV values preserved; `skill: false` disables routing); skill bodies are not injected. For coding tasks (write/edit tools, `worktree` or `allowTreeMutation`), skills whose `route-paths` globs match path-like tokens in the first 2,000 characters of the task text, or a top-level file of the `Repo root:` directory (else the cwd), are named first, then `software-design` and the rules/Kev picks, capped at `maxSkillsPerTask`.

- **Coding task** — `tools` includes `write`/`edit`, or `worktree: true` / `allowTreeMutation: true`.
- **Language detection** — skills whose `route-paths` globs match path-like tokens in the task text (containing `/`, ending in a file name with an extension, or a known extensionless name such as `Dockerfile`) or a top-level file of the `Repo root:` directory (or the working directory). Manual skills are never detected, and `main.lua` is not a signal (only `conf.lua` is, via the `love2d` skill's `route-paths`).
- **Precedence** — detected language skills and `software-design` are injected first without the Kev filter, then the usual rules + Kev picks are appended; duplicates and already-present skills are dropped; the total is capped at `maxSkillsPerTask`.
- **Shadow and off** — shadow mode logs decisions (with `wouldInject`) without mutating tasks; off mode does nothing.

**Commit check.** A `bash` command, or an `edit`/`write` with a `then_run` command, is checked for a real
`git commit` invocation. The check strips heredoc bodies (`<<EOF … EOF`, `<<'EOF'`, `<<-EOF`), ANSI-C `$'…'`
strings, single- and double-quoted string contents, and `#` comments, then looks for `git` at a command position
(start of line, after `; && || | (` `$(`, or after leading `VAR=value` assignments or `sudo`/`env`/`command`/`exec`)
followed by optional global options and the subcommand `commit`. When the gate blocks, the block reason includes the
full git-commit SKILL.md body behind the `[skill-router] git-commit skill loaded for this commit:` marker; the skill
arrives in the blocked call's error result so the agent can apply it and retry without a separate read.

**Edit/command gate.** An `edit`/`write` call whose path matches a skill's `metadata.route-paths`, or whose
`then_run.command` (or a `bash` command) matches its `route-commands`, is blocked once so the agent receives the skill.
The check runs after subagent routing and the commit gate; a real `git commit` is handled by the commit gate only.
Matched skills that are not already in context (compaction-aware) are delivered, ordered by name and capped at
`maxSkillsPerTask`. The block reason starts with `[skill-router] skills loaded for this call: <names>`, then the skill
bodies; because it sits at position 0 of an error result, later calls see the skills as in context and pass. Pi
appends tool results only after a whole assistant message's batch, so parallel sibling calls cannot see each other's
blocks: the router keeps a per-turn set (cleared on `turn_start`), and a sibling needing only already-delivered skills
gets a short `... delivered in a sibling call this turn; read it there, then retry.` block without bodies. The gate
fails open: any error allows the call. It runs only in `inject` mode (`shadow` and `off` skip it), ignores manual
skills, and applies in subagent and workflow children because they load this extension too.

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
| `maxSkillsPerTurn` | number > 0 | `2` | Most skills injected per user turn and per subagent task (non-coding). |
| `maxSkillsPerTask` | number > 0 | `3` | Most skills named per subagent coding task (language + software-design + Kev picks). |

What leaves the Pi process: the working directory and the first 2,000 characters of each prompt and subagent task,
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
npx tsx --test pi/.pi/agent/extensions/skill-router.test.ts
```

The frontmatter and keyword tests run the shared vectors in
`~/.pi/agent/skill-profiles/all/skill-creator/references/routing-vectors.json` and fail if that file is missing.
Routing tests use synthetic catalogs written to temp directories; no session text is stored in this repo.
