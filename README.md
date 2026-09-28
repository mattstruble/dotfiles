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

`pi/.pi/agent/extensions/skill-router.ts` injects the skills each Pi turn and each dispatched subagent task needs,
filtered by the local [Kev Decision Server](#kev-decision-server), and replaces `skill-enforcer.ts`. How it chooses
skills, every configuration option, and the tests are in
[`pi/.pi/agent/extensions/skill-router.md`](pi/.pi/agent/extensions/skill-router.md). To roll back, set
`"mode": "off"` in `pi/.pi/agent/skill-router.json` and restart Pi.

## Kev Decision Server

A local Kev model server that answers noul (yes/no probability) questions for
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

**Model per host:** `services.kev-server.model` defaults to `jaredpalmer/kev-0.8b` (idle ~2.0 GB, ~2.3 GB after
warm-up, ~31-35 ms for 1-2 questions, measured 2026-09-25). MacStruble (64 GB) overrides it with
`jaredpalmer/kev-4b` and raises the MLX limits to 20 GiB / 1 GiB cache in `nix-darwin/hosts/MacStruble/home.nix`;
Kev-4B needs ~9 GB of weights and peaks around 17 GB while loading. MLX limits are advisory: MLX may exceed them
under pressure.

**Interpreter:** Nix's `python312` (store path in the venv's `pyvenv.cfg`);
`UV_PYTHON_DOWNLOADS=never` prevents uv from downloading its own CPython.

**Security:** the server is unauthenticated on loopback — any local process can
query it. `kev.serve` supports bearer auth via `KEV_API_KEY`, but the
nix-darwin module does not set it.

**Updating:** the Kev code is pinned by `rev` and `hash` in `nix-darwin/modules/kev-server.nix`; the model is
pinned by the `@<revision>` suffix of `services.kev-server.model`. Change either and rebuild.

**Corporate-host constraints:** the venv is created with `uv --no-config`
because the global `uv.toml` adds a corporate index that doesn't carry MLX
packages. PyPI and Hugging Face Hub access is needed on first rebuild.

### Activate

1. Rebuild with `make rebuild` (stage any new files first: the flake only sees tracked files), or without git:
   ```bash
   sudo darwin-rebuild switch \
     --flake "path:$HOME/dotfiles/nix-darwin#$(hostname -s)" --impure
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
