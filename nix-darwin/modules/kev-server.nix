{ config, lib, pkgs, ... }:

let
  cfg = config.services.kev-server;
  homeDir = config.home.homeDirectory;

  # Pin the Kev source by revision — the venv is created outside the store
  # so uv sync can write to it while the source tree stays read-only.
  kevSrc = pkgs.fetchFromGitHub {
    owner = "jaredpalmer";
    repo = "kev";
    rev = "f2bb629d670f5b746f712fc05550a098526c836b";
    hash = "sha256-nj2gV40Ya6fxjouMe8i977zbclPl8qTMPjvrGkPAqO8=";
  };

  pythonInterp = "${pkgs.python312}/bin/python3.12";

  stateDir = "${homeDir}/.local/share/kev-server";
  venvDir = "${stateDir}/venv";
  stampFile = "${stateDir}/sync.stamp";
  prefetchStampFile = "${stateDir}/prefetch.stamp";
  lockFile = "${stateDir}/sync.lock";
  logFile = "${homeDir}/Library/Logs/kev-server.log";
  maxLogBytes = 10485760; # 10 MiB

  # Boot script: set MLX limits, then run kev.serve.  All tunables arrive via
  # environment variables so nothing is interpolated into a python -c string.
  bootScript = pkgs.writeText "kev-server-boot.py" ''
    import os, sys, runpy
    import mlx.core as mx

    mx.set_memory_limit(int(os.environ["KEV_MEMORY_LIMIT_BYTES"]))
    mx.set_cache_limit(int(os.environ["KEV_CACHE_LIMIT_BYTES"]))

    sys.argv = [
        "kev.serve",
        "--run", os.environ["KEV_MODEL"],
        "--host", os.environ["KEV_HOST"],
        "--port", os.environ["KEV_PORT"],
    ]
    runpy.run_module("kev.serve", run_name="__main__")
  '';

  # Prefetch script: download the pinned checkpoint and its base model into HF cache.
  # Uses huggingface_hub.snapshot_download directly — cheap when already cached.
  # Does NOT load the model into memory.
  prefetchScript = pkgs.writeText "kev-server-prefetch.py" ''
    import json, os, sys
    from pathlib import Path

    import torch
    from huggingface_hub import snapshot_download

    model_spec = os.environ["KEV_MODEL"]
    repo, _, revision = model_spec.partition("@")
    revision = revision or None

    print(f"[prefetch] checkpoint: {repo}@{revision or 'HEAD'}")
    ck_path = snapshot_download(
        repo, revision=revision,
        allow_patterns=["*.json", "*.safetensors", "*.pt", "*.txt", "*.jinja"],
    )
    print(f"[prefetch] checkpoint cached at {ck_path}")

    # Read head.pt to find the base model and revision (weights_only for safety)
    meta = torch.load(f"{ck_path}/head.pt", map_location="cpu", weights_only=True)
    base = meta.get("base")
    base_rev = meta.get("base_revision")
    if not base:
        print("[prefetch] no base in head.pt, skipping base download")
        sys.exit(0)

    print(f"[prefetch] base model: {base}@{base_rev or 'HEAD'}")
    base_path = snapshot_download(
        base, revision=base_rev or None,
        allow_patterns=["*.json", "*.safetensors", "*.txt", "*.jinja", "*.model"],
    )
    print(f"[prefetch] base cached at {base_path}")

    # Write resolved base revision so the shell stamp captures it
    stamp_path = os.environ.get("PREFETCH_STAMP_FILE")
    if stamp_path:
        Path(stamp_path).write_text(f"{model_spec}:{base_rev or 'HEAD'}\n")
  '';

  # Shared sync script used by both the activation step and the wrapper as fallback.
  # Arguments:
  #   $1 = "activation" or "wrapper" (controls best-effort vs hard-fail)
  #   $2 = "prefetch" to also run the prefetch step (activation only)
  syncScript = pkgs.writeShellScript "kev-server-sync" ''
    set -uo pipefail

    MODE="''${1:-wrapper}"
    DO_PREFETCH="''${2:-}"

    STATE_DIR="${stateDir}"
    VENV_DIR="${venvDir}"
    STAMP_FILE="${stampFile}"
    PREFETCH_STAMP="${prefetchStampFile}"
    LOCK_FILE="${lockFile}"
    KEV_SOURCE="${cfg.kevSource}"
    PYTHON="${pythonInterp}"
    UV="${pkgs.uv}/bin/uv"
    FLOCK="${pkgs.flock}/bin/flock"

    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"

    export UV_PROJECT_ENVIRONMENT="$VENV_DIR"
    export UV_PYTHON_DOWNLOADS=never

    # --- Kernel-managed lock via flock(1) ---
    # The lock is released automatically when the process exits (fd closed).
    exec 9>"$LOCK_FILE"
    if [ "$MODE" = "wrapper" ]; then
      if ! "$FLOCK" -w 120 9; then
        echo "[$(date -Iseconds)] FATAL: could not acquire sync lock after 120s" >&2
        exit 1
      fi
    else
      # Activation: non-blocking, skip if another sync is running
      if ! "$FLOCK" -n 9; then
        echo "[$(date -Iseconds)] sync lock held by another process, skipping"
        exit 0
      fi
    fi

    # --- Stamp check: keyed on kev source, uv.lock hash, AND python interpreter ---
    lock_hash=$(${pkgs.coreutils}/bin/md5sum "$KEV_SOURCE/uv.lock" | cut -d' ' -f1)
    want="$KEV_SOURCE:''${lock_hash}:$PYTHON"
    current=""
    [ -f "$STAMP_FILE" ] && current=$(cat "$STAMP_FILE")

    if [ "$want" != "$current" ]; then
      echo "[$(date -Iseconds)] syncing venv (stamp mismatch)"
      echo "[$(date -Iseconds)]   want:    $want"
      echo "[$(date -Iseconds)]   current: $current"

      # setuptools writes kev.egg-info into the project dir during `uv sync`,
      # and the Nix store copy is read-only. Work around this with a writable
      # temp directory that symlinks every top-level entry from the store path.
      sync_src=$(mktemp -d)
      cleanup_src() { rm -rf "$sync_src"; }
      trap 'cleanup_src' EXIT
      for f in "$KEV_SOURCE"/*; do
        ln -s "$f" "$sync_src/$(basename "$f")"
      done

      if $UV --no-config sync --frozen --extra serve \
          --python "$PYTHON" --project "$sync_src" 2>&1; then
        rm -rf "$sync_src"
        trap - EXIT
        echo "$want" > "$STAMP_FILE"
        echo "[$(date -Iseconds)] sync complete"
      else
        rc=$?
        rm -rf "$sync_src"
        trap - EXIT
        if [ "$MODE" = "activation" ]; then
          echo "WARNING: kev-server venv sync failed (rc=$rc); agent will retry at start" >&2
          exit 0
        fi
        exit $rc
      fi
    else
      echo "[$(date -Iseconds)] venv up to date, skipping sync"
    fi

    # --- Prefetch weights (activation only, best-effort) ---
    if [ "$DO_PREFETCH" = "prefetch" ] && [ -x "$VENV_DIR/bin/python" ]; then
      export HF_HOME="${homeDir}/.cache/huggingface"
      export KEV_MODEL="${cfg.model}"
      export PREFETCH_STAMP_FILE="$PREFETCH_STAMP"

      # Skip if the prefetch stamp already matches the model spec
      prefetch_current=""
      [ -f "$PREFETCH_STAMP" ] && prefetch_current=$(head -1 "$PREFETCH_STAMP")
      if echo "$prefetch_current" | grep -q "^''${KEV_MODEL}:"; then
        echo "[$(date -Iseconds)] prefetch up to date (stamp matches), skipping"
      else
        echo "[$(date -Iseconds)] prefetching model weights..."
        if "$VENV_DIR/bin/python" "${prefetchScript}" 2>&1; then
          echo "[$(date -Iseconds)] prefetch complete"
        else
          echo "WARNING: kev-server weight prefetch failed; agent will download at start" >&2
        fi
      fi
    fi

    exit 0
  '';

  # Wrapper shell script — handles log rotation, port conflict detection,
  # then delegates to the sync script and exec's into the Python boot script.
  wrapper = pkgs.writeShellScript "kev-server-wrapper" ''
    set -euo pipefail

    export UV_PROJECT_ENVIRONMENT="${venvDir}"

    # --- Log rotation: truncate when > ~10 MiB at start ---
    if [ -f "${logFile}" ]; then
      sz=$(stat -f%z "${logFile}" 2>/dev/null || echo 0)
      if [ "$sz" -gt ${toString maxLogBytes} ]; then
        tail -c ${toString maxLogBytes} "${logFile}" > "${logFile}.tmp"
        cat "${logFile}.tmp" > "${logFile}"
        rm -f "${logFile}.tmp"
        echo "[$(date -Iseconds)] log rotated (was $sz bytes)" >> "${logFile}"
      fi
    fi

    # --- Port conflict detection ---
    if /usr/sbin/lsof -iTCP:${toString cfg.port} -sTCP:LISTEN -P -n >/dev/null 2>&1; then
      echo "[$(date -Iseconds)] FATAL: port ${toString cfg.port} already in use; exiting" >&2
      exit 1
    fi

    # --- Sync venv (fallback — activation should have done this already) ---
    "${syncScript}" wrapper

    # --- Exec the server ---
    exec "${venvDir}/bin/python" "${bootScript}"
  '';
in
{
  options.services.kev-server = {
    enable = lib.mkEnableOption "Kev decision server (local 0.8B model for Pi skill routing)";

    kevSource = lib.mkOption {
      type = lib.types.path;
      default = kevSrc;
      description = "Path to the Kev source tree (must contain pyproject.toml and uv.lock).";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e";
      description = "HuggingFace model identifier for the Kev run. Pinned to a Hub revision via @rev.";
    };

    host = lib.mkOption {
      type = lib.types.enum [ "127.0.0.1" "::1" "localhost" ];
      default = "127.0.0.1";
      description = "Address to bind (must be loopback: 127.0.0.1, ::1, or localhost).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8008;
      description = "TCP port for the Kev server.";
    };

    memoryLimitBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4294967296; # 4 GiB
      description = "MLX metal memory limit in bytes (advisory — MLX may exceed this under pressure).";
    };

    cacheLimitBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 268435456; # 256 MiB
      description = "MLX metal free-cache limit in bytes (advisory).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Sync the venv and prefetch weights before launchd agents are set up.
    # Best-effort: failures print a warning and return success so the switch never fails.
    # Bounded by timeout so a stalled network cannot hang darwin-rebuild switch.
    home.activation.kevServerSync =
      lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
        if [ -z "''${DRY_RUN:-}" ]; then
          echo "kev-server: syncing venv and prefetching weights (best-effort, 600s timeout)..."
          rc=0
          "${pkgs.coreutils}/bin/timeout" 600 "${syncScript}" activation prefetch || rc=$?
          if [ "$rc" -eq 124 ]; then
            echo "WARNING: kev-server sync timed out after 600s; agent will finish at start" >&2
          elif [ "$rc" -ne 0 ]; then
            echo "WARNING: kev-server sync exited $rc; agent will retry at start" >&2
          fi
        else
          echo "kev-server: would sync venv and prefetch weights"
        fi
      '';

    launchd.agents.kev-server = {
      enable = true;
      config = {
        Label = "com.user.kev-server";
        ProgramArguments = [ "${wrapper}" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
        # Restart on crash, but back off to avoid tight loops
        ThrottleInterval = 10;
        EnvironmentVariables = {
          HOME = homeDir;
          HF_HOME = "${homeDir}/.cache/huggingface";
          PATH = lib.concatStringsSep ":" [
            "${pkgs.coreutils}/bin"
            "${pkgs.python312}/bin"
            "/usr/bin"
            "/bin"
          ];
          KEV_MODEL = cfg.model;
          KEV_HOST = cfg.host;
          KEV_PORT = toString cfg.port;
          KEV_MEMORY_LIMIT_BYTES = toString cfg.memoryLimitBytes;
          KEV_CACHE_LIMIT_BYTES = toString cfg.cacheLimitBytes;
        };
      };
    };
  };
}
