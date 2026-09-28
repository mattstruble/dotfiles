# Dotfiles

This repository contains the dotfiles which I use in my development environment
to install download the repository to your root dir (`~`) and call `make`.

## External Configurations

Independent application configurations to make a better unified user experience.

### macos

#### Accessibility

1. Open up the accessibility menu within system settings
2. Navigate to display and ensure `Reduce motion` is enabled

#### Keyboard

1. Open up the keyboard menu within system settings
2. Open up Keyboard shortcuts
3. Select Modifier keys
4. Set Caps Lock to be Escape. (Easier vim navigation)

### iterm2

#### Colors

1. Open up iterm2 settings and navigate to Profiles > Colors.
2. Import `colors/coolnight.itermcolors` under color presets and then select it.

#### Fontsize

1. Open up iterm2 settings and navigate to Profiles > Text.
2. Set the font size to be around `18`

## References

This repository wouldn't be possible without the help of others
and their own dotfile repositories.

- <https://github.com/dorrajmachai/nvim>
- <https://github.com/ThePrimeagen/.dotfiles>
- <https://github.com/josean-dev/dev-environment-files>
- <https://github.com/younger-1/nvim/>
- <https://github.com/avocadeys/NVCat>
- <https://github.com/aorith/dotfiles>
- <https://github.com/mcauley-penney/nvim>

## Skill Router

Automatic skill injection for Pi sessions and dispatched sub-agents.
Replaces `skill-enforcer.ts`.

**Per turn (`before_agent_start`):**
1. Score the prompt against named-skill rules (exact catalog name → 1.0) and
   enforcer patterns (regex → 0.75).
2. If there are hits and the decider is reachable, query it to keep or drop
   each hit (threshold 0.30). A *noul* is the decider's yes/no probability
   for a question — skills below the threshold are dropped.
3. Select top 2 skills (by score desc, name desc) not already in context.
4. Inject their bodies as `custom_message` entries and replace the verbose
   `<available_skills>` block with a names-only list.
5. Block `git commit` until `git-commit` is in context.

**Per dispatch (`tool_call` on `dispatch`):**
Each sub-agent task is scored and injected independently (same rules + decider
filter). `shadow` mode logs `wouldInject` without mutating.

**What leaves the Pi process:** the router sends the working directory and the
first 2 000 characters of each user prompt (and of each dispatched task's text)
to the configured decider. The default decider is the local
[Kev Decision Server](#kev-decision-server) on `127.0.0.1:8008`. Plain `http://`
is refused for non-loopback hosts. `https://` to a remote host is allowed with
a one-time warning that prompts leave the machine. A hosted decider's API key
comes from the env var named by `apiKeyEnv` — never from the JSON file.

**Configuration** (`pi/.pi/agent/skill-router.json`, linked to `~/.pi/agent/`):

| Key | Default | Description |
|-----|---------|-------------|
| `mode` | `"inject"` | `inject` (live), `shadow` (log only), `off` (disabled) |
| `decider.url` | `"http://127.0.0.1:8008"` | Kev server URL |
| `decider.model` | `"kev-latest"` | Model name sent to `/v1/systemone` |
| `decider.timeoutMs` | `1500` | Per-query timeout; fallback to rules on failure |
| `decider.threshold` | `0.30` | Minimum noul probability to keep a hit |
| `decider.apiKeyEnv` | `null` | Env var name for bearer auth |
| `catalog` | `"~/.pi/agent/skill-profiles/all"` | Skill catalog directory |
| `maxSkillsPerTurn` | `2` | Max skills injected per turn/task |

**Rollback:** set `"mode": "off"` in `pi/.pi/agent/skill-router.json` (an
out-of-store symlink, so no rebuild is needed) and restart Pi sessions — the
config is read when the extension loads. `"shadow"` logs decisions without
injecting.

### Tests

```bash
# Unit + parity (no server needed)
npx tsx --test pi/.pi/agent/extensions/skill-router.test.ts \
  pi/.pi/agent/extensions/skill-router-parity.test.ts

# Kev parity (requires running Kev server on :8008)
npx tsx --test pi/.pi/agent/extensions/skill-router-kev-parity.test.ts
```

## Kev Decision Server

A local 0.8B model server that answers noul (yes/no probability) questions for
the [Skill Router](#skill-router). Loopback only, `127.0.0.1:8008`. Managed as
a launchd user agent via nix-darwin — enabled on every host from the shared
`nix-darwin/home.nix`.

**Endpoints:** `POST /v1/systemone` (noul answers), `GET /v1/models` (health check).

**Start / stop / restart:**
```bash
launchctl start gui/$(id -u)/com.user.kev-server
launchctl stop gui/$(id -u)/com.user.kev-server
launchctl kickstart -k gui/$(id -u)/com.user.kev-server
```

**Logs:** `~/Library/Logs/kev-server.log` (auto-truncated at ~10 MiB on restart).

**Memory:** MLX advisory limits are set to 4 GiB / 256 MiB cache, but MLX may
exceed them under pressure. Idle ~2.1 GB after warm-up, warm latency ~31–35 ms
for 1–2 questions (measured 2026-09-25).

**Interpreter:** Nix's `python312` (store path in the venv's `pyvenv.cfg`);
`UV_PYTHON_DOWNLOADS=never` prevents uv from downloading its own CPython.

**Security:** the server is unauthenticated on loopback — any local process can
query it. `kev.serve` supports bearer auth via `KEV_API_KEY`, but the
nix-darwin module does not set it.

**Updating the model revision:** edit the `rev` and `hash` in
`nix-darwin/modules/kev-server.nix`, then rebuild. The `model` field in the
module controls the HF revision passed to `kev.serve --run`.

**Corporate-host constraints:** the venv is created with `uv --no-config`
because the global `uv.toml` adds a corporate index that doesn't carry MLX
packages. PyPI and Hugging Face Hub access is needed on first rebuild.

### Activate

1. `git add` any untracked files, then rebuild:
   ```bash
   sudo darwin-rebuild switch \
     --flake "path:$HOME/dotfiles/nix-darwin#$(hostname)" --impure
   ```
2. The rebuild syncs a Python env (torch, MLX, transformers and
   dependencies) from PyPI via `uv --no-config` and prefetches the pinned
   HF checkpoint and base weights (a few GB on first rebuild). Both steps
   are best-effort and bounded by a 600 s timeout — failures print a
   warning and the agent retries at start. A `flock(1)` lock prevents
   concurrent syncs.
3. Verify the server is running:
   ```bash
   curl -s http://127.0.0.1:8008/v1/models
   ```
4. Restart Pi sessions so the extension picks up the new config.
