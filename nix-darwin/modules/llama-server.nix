{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.llama-server;

  args = lib.concatStringsSep " " (
    [
      "--hf-repo"
      cfg.hfRepo
      "--hf-file"
      cfg.hfFile
      "--port"
      (toString cfg.port)
      "-c"
      (toString cfg.contextSize)
      "-b"
      (toString cfg.batchSize)
      "-ub"
      (toString cfg.uBatchSize)
      "-ngl"
      (toString cfg.gpuLayers)
      "--cache-reuse"
      (toString cfg.cacheReuse)
      "-dt"
      cfg.defragThreshold
    ]
    ++ lib.optional cfg.flashAttn "-fa"
    ++ cfg.extraArgs
  );
in
{
  options.services.llama-server = {
    enable = lib.mkEnableOption "llama-server FIM service for llama.vim";

    hfRepo = lib.mkOption {
      type = lib.types.str;
      description = "Hugging Face repo to download the model from (e.g. ggerganov/Qwen2.5-Coder-1.5B-Q8_0-GGUF)";
    };

    hfFile = lib.mkOption {
      type = lib.types.str;
      description = "GGUF filename within the HF repo";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8012;
      description = "Port llama-server listens on";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = "KV cache context size in tokens (-c)";
    };

    batchSize = lib.mkOption {
      type = lib.types.int;
      default = 1024;
      description = "Max tokens per prompt processing batch (-b)";
    };

    uBatchSize = lib.mkOption {
      type = lib.types.int;
      default = 512;
      description = "Physical micro-batch size (-ub)";
    };

    gpuLayers = lib.mkOption {
      type = lib.types.int;
      default = 99;
      description = "Number of model layers to offload to Metal GPU (-ngl). 99 offloads all layers.";
    };

    flashAttn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Flash Attention (-fa). Reduces memory usage for large contexts.";
    };

    cacheReuse = lib.mkOption {
      type = lib.types.int;
      default = 256;
      description = "Minimum KV cache chunk size in tokens to reuse via context shifting (--cache-reuse).";
    };

    defragThreshold = lib.mkOption {
      type = lib.types.str;
      default = "0.1";
      description = "KV cache defragmentation threshold (-dt). 0.1 triggers defrag when 10% fragmented.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional raw arguments passed verbatim to llama-server";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.llama-server = {
      command = "${pkgs.llama-cpp}/bin/llama-server ${args}";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/llama-server.log";
        StandardErrorPath = "/tmp/llama-server.log";
      };
    };
  };
}
