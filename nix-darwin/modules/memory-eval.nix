{ config, lib, pkgs, ... }:

let
  cfg = config.services.memory-eval;
  homeDir = config.home.homeDirectory;

  pythonInterp = "${pkgs.python312}/bin/python3.12";
  hindsightVersion = "1.1.0";
  maxLogBytes = 10485760; # 10 MiB

  # Hindsight
  hsDir = "${homeDir}/.local/share/hindsight";
  hsVenv = "${hsDir}/venv";
  hsStamp = "${hsDir}/install.stamp";
  hsLock = "${hsDir}/install.lock";
  hsLog = "${homeDir}/Library/Logs/hindsight.log";

  # Cognee (own venv: its litellm/lancedb/fastapi pins conflict with the gateway lockfile)
  cgDir = "${homeDir}/.local/share/cognee";
  cgVenv = "${cgDir}/venv";
  cgStamp = "${cgDir}/install.stamp";
  cgLock = "${cgDir}/install.lock";
  cgLog = "${homeDir}/Library/Logs/cognee.log";

  # Memory gateway
  gwDir = "${homeDir}/.local/share/memory-gateway";
  gwVenv = "${gwDir}/venv";
  gwStamp = "${gwDir}/sync.stamp";
  gwLock = "${gwDir}/sync.lock";
  gwLog = "${homeDir}/Library/Logs/memory-gateway.log";

  rotateLog = log: ''
    if [ -f "${log}" ]; then
      sz=$(stat -f%z "${log}" 2>/dev/null || echo 0)
      if [ "$sz" -gt ${toString maxLogBytes} ]; then
        tail -c ${toString maxLogBytes} "${log}" > "${log}.tmp"
        cat "${log}.tmp" > "${log}"
        rm -f "${log}.tmp"
        echo "[$(date -Iseconds)] log rotated (was $sz bytes)" >> "${log}"
      fi
    fi
  '';

  # $1 = activation | wrapper
  lockPrelude = dir: lock: ''
    set -uo pipefail
    MODE="''${1:-wrapper}"
    mkdir -p "${dir}"
    chmod 700 "${dir}"
    export UV_PYTHON_DOWNLOADS=never
    exec 9>"${lock}"
    if [ "$MODE" = "wrapper" ]; then
      if ! ${pkgs.flock}/bin/flock -w 600 9; then
        echo "[$(date -Iseconds)] FATAL: could not acquire sync lock" >&2
        exit 1
      fi
    else
      if ! ${pkgs.flock}/bin/flock -n 9; then
        echo "[$(date -Iseconds)] sync lock held by another process, skipping"
        exit 0
      fi
    fi
  '';

  hsSync = pkgs.writeShellScript "hindsight-sync" ''
    ${lockPrelude hsDir hsLock}
    UV="${pkgs.uv}/bin/uv"
    want="hindsight-api==${hindsightVersion}:${pythonInterp}"
    current=""
    [ -f "${hsStamp}" ] && current=$(cat "${hsStamp}")
    if [ "$want" != "$current" ] || [ ! -x "${hsVenv}/bin/hindsight-api" ]; then
      echo "[$(date -Iseconds)] installing hindsight-api==${hindsightVersion}"
      if $UV venv --allow-existing --python "${pythonInterp}" "${hsVenv}" 2>&1 \
         && $UV pip install --python "${hsVenv}/bin/python" "hindsight-api==${hindsightVersion}" 2>&1; then
        echo "$want" > "${hsStamp}"
      else
        rc=$?
        if [ "$MODE" = "activation" ]; then
          echo "WARNING: hindsight install failed (rc=$rc); agent will retry at start" >&2
          exit 0
        fi
        exit $rc
      fi
    else
      echo "[$(date -Iseconds)] hindsight up to date, skipping install"
    fi
    exit 0
  '';

  hsWrapper = pkgs.writeShellScript "hindsight-wrapper" ''
    set -euo pipefail
    umask 077
    ${rotateLog hsLog}
    "${hsSync}" wrapper
    exec "${hsVenv}/bin/hindsight-api" --host 127.0.0.1 --port ${toString cfg.hindsightPort}
  '';

  cgSync = pkgs.writeShellScript "cognee-sync" ''
    ${lockPrelude cgDir cgLock}
    UV="${pkgs.uv}/bin/uv"
    want="cognee[aws]==${cfg.cogneeVersion}:${pythonInterp}"
    current=""
    [ -f "${cgStamp}" ] && current=$(cat "${cgStamp}")
    if [ "$want" != "$current" ] || [ ! -x "${cgVenv}/bin/python" ]; then
      echo "[$(date -Iseconds)] installing cognee[aws]==${cfg.cogneeVersion}"
      if $UV venv --allow-existing --python "${pythonInterp}" "${cgVenv}" 2>&1 \
         && $UV pip install --python "${cgVenv}/bin/python" "cognee[aws]==${cfg.cogneeVersion}" 2>&1; then
        echo "$want" > "${cgStamp}"
      else
        rc=$?
        if [ "$MODE" = "activation" ]; then
          echo "WARNING: cognee install failed (rc=$rc); agent will retry at start" >&2
          exit 0
        fi
        exit $rc
      fi
    else
      echo "[$(date -Iseconds)] cognee up to date, skipping install"
    fi
    exit 0
  '';

  cgWrapper = pkgs.writeShellScript "cognee-wrapper" ''
    set -euo pipefail
    umask 077
    mkdir -p "${cgDir}/data" "${cgDir}/system"
    chmod 700 "${cgDir}" "${cgDir}/data" "${cgDir}/system"
    ${rotateLog cgLog}
    "${cgSync}" wrapper
    exec "${cgVenv}/bin/python" -m cognee.api.client
  '';

  gwSync = pkgs.writeShellScript "memory-gateway-sync" ''
    ${lockPrelude gwDir gwLock}
    UV="${pkgs.uv}/bin/uv"
    SRC="${cfg.sourceDir}"
    export UV_PROJECT_ENVIRONMENT="${gwVenv}"
    if [ ! -f "$SRC/uv.lock" ]; then
      echo "memory-gateway: $SRC/uv.lock not found" >&2
      [ "$MODE" = "activation" ] && exit 0
      exit 1
    fi
    lock_hash=$(${pkgs.coreutils}/bin/sha256sum "$SRC/uv.lock" | cut -d' ' -f1)
    want="$SRC:$lock_hash:${pythonInterp}"
    current=""
    [ -f "${gwStamp}" ] && current=$(cat "${gwStamp}")
    if [ "$want" != "$current" ]; then
      echo "[$(date -Iseconds)] syncing memory-gateway venv"
      if $UV --no-config sync --frozen --python "${pythonInterp}" --project "$SRC" 2>&1; then
        echo "$want" > "${gwStamp}"
      else
        rc=$?
        if [ "$MODE" = "activation" ]; then
          echo "WARNING: memory-gateway sync failed (rc=$rc); agent will retry at start" >&2
          exit 0
        fi
        exit $rc
      fi
    else
      echo "[$(date -Iseconds)] venv up to date, skipping sync"
    fi
    exit 0
  '';

  gwWrapper = pkgs.writeShellScript "memory-gateway-wrapper" ''
    set -euo pipefail
    umask 077
    ${rotateLog gwLog}
    "${gwSync}" wrapper
    exec "${gwVenv}/bin/memory-gateway"
  '';

  agentPath = lib.concatStringsSep ":" [
    "${pkgs.coreutils}/bin"
    "${pkgs.python312}/bin"
    "/usr/bin"
    "/bin"
  ];

  gatewayConfig = {
    host = "127.0.0.1";
    port = cfg.gatewayPort;
    state_dir = gwDir;
    arms = cfg.arms;
    hindsight_url = "http://127.0.0.1:${toString cfg.hindsightPort}";
    hindsight_bank = "memory-sessions";
    arm_sources = { hindsight = [ "session" "retain" ]; };
    exclude_patterns = cfg.excludePatterns;
    bedrock_model = cfg.bedrockModel;
    aws_region = cfg.awsRegion;
    cognee_url = "http://127.0.0.1:${toString cfg.cogneePort}";
    wiki_source = "${homeDir}/llm-wiki";
  };

  clientConfig = {
    inherit (cfg) mode injectArm;
    gatewayUrl = "http://127.0.0.1:${toString cfg.gatewayPort}";
    startBudget = 2000;
    topupBudget = 1000;
  };
in
{
  options.services.memory-eval = {
    enable = lib.mkEnableOption "memory eval stack (Hindsight + memory-gateway)";

    awsProfile = lib.mkOption {
      type = lib.types.str;
      default = "bedrock";
      description = "AWS profile used for Bedrock.";
    };

    awsRegion = lib.mkOption {
      type = lib.types.str;
      default = "us-east-1";
      description = "AWS region used for Bedrock.";
    };

    bedrockModel = lib.mkOption {
      type = lib.types.str;
      default = "us.anthropic.claude-haiku-4-5-20251001-v1:0";
      description = "Bedrock model id used by Hindsight and the gateway.";
    };

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 8010;
      description = "Loopback port for memory-gateway.";
    };

    hindsightPort = lib.mkOption {
      type = lib.types.port;
      default = 8011;
      description = "Loopback port for Hindsight.";
    };

    cogneePort = lib.mkOption {
      type = lib.types.port;
      default = 8012;
      description = "Loopback port for the cognee API server.";
    };

    cogneeVersion = lib.mkOption {
      type = lib.types.str;
      default = "1.6.6";
      description = "cognee release installed into its own venv.";
    };

    arms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "hindsight" "graphiti" ];
      description = "Memory arms enabled in the gateway.";
    };

    excludePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "memory[-_]gateway"
        "memory[-_]eval"
        "supersession_pairs"
        "strict_judge"
        "scratch_hindsight"
        "calibration-(sheet|labels|cases)"
        "hindsight_twoway"
      ];
      description = "Regex patterns excluding content from memory ingestion.";
    };

    cognee.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the cognee launchd agent (large memory footprint).";
    };

    mode = lib.mkOption {
      type = lib.types.enum [ "off" "shadow" "inject" ];
      default = "shadow";
      description = "memory.ts client mode.";
    };

    injectArm = lib.mkOption {
      type = lib.types.str;
      default = "graphiti";
      description = "Arm whose results are injected when mode = inject.";
    };

    sourceDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDir}/dotfiles/memory-gateway";
      description = "Out-of-store checkout of the memory-gateway project (pyproject.toml + uv.lock).";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."memory-gateway/config.json".text = builtins.toJSON gatewayConfig;
    xdg.configFile."memory-gateway/client.json".text = builtins.toJSON clientConfig;

    home.activation.memoryEvalSync =
      lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
        if [ -z "''${DRY_RUN:-}" ]; then
          echo "memory-eval: syncing venvs (best-effort, 600s timeout)..."
          for s in "${hsSync}" ${lib.optionalString cfg.cognee.enable "${cgSync}"} "${gwSync}"; do
            rc=0
            "${pkgs.coreutils}/bin/timeout" 600 "$s" activation || rc=$?
            if [ "$rc" -ne 0 ]; then
              echo "WARNING: $s exited $rc; agent will retry at start" >&2
            fi
          done
        else
          echo "memory-eval: would sync venvs"
        fi
      '';

    launchd.agents.hindsight = {
      enable = true;
      config = {
        Label = "com.user.hindsight";
        ProgramArguments = [ "${hsWrapper}" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = hsLog;
        StandardErrorPath = hsLog;
        ThrottleInterval = 60;
        EnvironmentVariables = {
          PATH = agentPath;
          HINDSIGHT_API_LLM_PROVIDER = "bedrock";
          HINDSIGHT_API_LLM_MODEL = cfg.bedrockModel;
          AWS_REGION_NAME = cfg.awsRegion;
          AWS_REGION = cfg.awsRegion;
          AWS_PROFILE = cfg.awsProfile;
          HINDSIGHT_API_HOST = "127.0.0.1";
          HINDSIGHT_API_PORT = toString cfg.hindsightPort;
          HF_HUB_DISABLE_TELEMETRY = "1";
          HINDSIGHT_API_OTEL_TRACES_ENABLED = "false";
        };
      };
    };

    # Env names confirmed from cognee v1.6.6 .env.template / source: LLM_PROVIDER,
    # LLM_MODEL, EMBEDDING_*, DATA_ROOT_DIRECTORY, SYSTEM_ROOT_DIRECTORY,
    # ENABLE_BACKEND_ACCESS_CONTROL, TELEMETRY_DISABLED, AWS_REGION, AWS_PROFILE_NAME,
    # HTTP_API_HOST/HTTP_API_PORT (cognee.api.client __main__). Unconfirmed:
    # the "bedrock/" model prefix (passed through to LiteLLM) and whether
    # EMBEDDING_DIMENSIONS is required for fastembed (set anyway); LITELLM_LOG
    # and AWS_PROFILE are read by litellm/boto3, not cognee.
    launchd.agents.cognee = lib.mkIf cfg.cognee.enable {
      enable = true;
      config = {
        Label = "com.user.cognee";
        ProgramArguments = [ "${cgWrapper}" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = cgLog;
        StandardErrorPath = cgLog;
        ThrottleInterval = 60;
        EnvironmentVariables = {
          PATH = agentPath;
          HTTP_API_HOST = "127.0.0.1";
          HTTP_API_PORT = toString cfg.cogneePort;
          DATA_ROOT_DIRECTORY = "${cgDir}/data";
          SYSTEM_ROOT_DIRECTORY = "${cgDir}/system";
          ENABLE_BACKEND_ACCESS_CONTROL = "false";
          TELEMETRY_DISABLED = "1";
          # Cognee defaults both to 1<<35 (32 GiB); cap the buffer pool on this 24 GB host.
          KUZU_BUFFER_POOL_SIZE = "2147483648"; # 1<<31 (2 GiB)
          # Mapping limit (address space), not disk use; 32 GiB was hit at ~400 docs.
          KUZU_MAX_DB_SIZE = "274877906944"; # 1<<38 (256 GiB)
          LITELLM_LOG = "ERROR";
          LLM_PROVIDER = "bedrock";
          LLM_MODEL = "bedrock/${cfg.bedrockModel}";
          AWS_PROFILE = cfg.awsProfile;
          AWS_PROFILE_NAME = cfg.awsProfile;
          AWS_REGION = cfg.awsRegion;
          AWS_REGION_NAME = cfg.awsRegion;
          EMBEDDING_PROVIDER = "fastembed";
          EMBEDDING_MODEL = "BAAI/bge-small-en-v1.5";
          EMBEDDING_DIMENSIONS = "384";
          HF_HUB_DISABLE_TELEMETRY = "1";
        };
      };
    };

    launchd.agents.memory-gateway = {
      enable = true;
      config = {
        Label = "com.user.memory-gateway";
        ProgramArguments = [ "${gwWrapper}" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = gwLog;
        StandardErrorPath = gwLog;
        ThrottleInterval = 60;
        EnvironmentVariables = {
          PATH = agentPath;
          MEMORY_GATEWAY_CONFIG = "${homeDir}/.config/memory-gateway/config.json";
          AWS_PROFILE = cfg.awsProfile;
          AWS_REGION = cfg.awsRegion;
          GRAPHITI_TELEMETRY_ENABLED = "false";
          HF_HUB_DISABLE_TELEMETRY = "1";
        };
      };
    };
  };
}
