{
  inputs,
  ...
}:
let
  userName = import ./username.nix;
  ca-bundle_path = "/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-certificates.crt";
in
{
  "${userName}" =
    {
      config,
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [
        ../../profiles/macos.nix
        ../../home.nix
        ../../modules/zen-browser.nix
      ];
      _module.args = {
        ca-bundle_path = ca-bundle_path;
        ca-bundle_crt = ca-bundle_crt;
      };

      sops = {
        defaultSopsFile = ./secrets.yaml;
        secrets = {
          n8n-mcp-token = { };
          litellm-key = { };
        };
      };

      programs.pi-mcp.servers.n8n = {
        url = "http://roque:5678/mcp-server/http";
        headers.Authorization = "!echo Bearer $(cat ${config.sops.secrets.n8n-mcp-token.path})";
        description = "Trigger and manage n8n workflows on the home server.";
      };

      services.llm-wiki.remoteUrl = "git@github-llm-wiki:mattstruble/llm-wiki.git";

      programs.obsidian.vaults.garden.target = "Documents/garden";

      home.file.".ssh/id_ed25519_mattstruble.pub".text =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL+QzypEEYDWtg6jJ1siaNho4ZdwsczWwTZWySAZdkm\n";

      # Two cards = two models awake at a time, so cap workflow and subagent
      # children at two. A child aimed at a sleeping model also pays a wake.
      programs.pi-workflows.settings.defaultConcurrency = 2;
      programs.pi-subagents.config = {
        globalConcurrencyLimit = 2;
        parallel.concurrency = 2;
        # 60 min: the 30 min default kills agents that are actively working.
        # Traced from session timestamps (2026-11-15): a flash-next coder with
        # 199k input / cacheRead=0 was killed at exactly 30m on turn 10 — still
        # making real progress, each turn 82-263s (turn 1 includes model wake,
        # later turns grow as context accumulates). It would have finished in
        # ~45m. Concurrent --batch 2 coders are faster than sequential (tool
        # I/O overlaps with GPU decode), so the fleet stays on-demand as-is.
        timeoutMs = 3600000;
        # One retry: recovers from cold-cache first turns and transient slot
        # contention without doubling cost on every failure.
        agentRetries = 1;
        # Block the main agent until subagents/workflows finish (foreground by
        # default). Two reasons: (1) pi-caffeinate tracks activeTurns via
        # agent_start/agent_end — an async workflow ends the main turn,
        # activeTurns hits 0, caffeinate stops, and the computer sleeps,
        # suspending the background runner mid-work. Foreground keeps the turn
        # alive so caffeinate stays on. (2) The result is needed inline anyway
        # for review/orchestrator workflows. Internal workflow parallelism via
        # parallel()/pipeline() is unaffected — children still run concurrently.
        # Pass async:true explicitly for genuine fire-and-forget work.
        asyncByDefault = false;
      };

      home.file.".pi/agent/models.json".source = pkgs.writeText "pi-models.json" (
        builtins.toJSON {
          providers = {
            # One provider -> the LiteLLM gateway (:8000). Model ids are the fleet
            # values' `modelName` (the gateway route), not the deployment name.
            # Every model is on-demand since 2026-10-12: the swapper wakes one on the
            # first request (measured 86-145 s to first token, cold or warm) and
            # sleeps it after an idle ttl (900 s, flash-next 1800 s). The wake streams
            # loading remarks, so pi's 5-minute httpIdleTimeoutMs covers it - do not
            # lower that. Two cards means two models can be awake at once; the swapper
            # places each wake on whichever card is free.
            #
            # `reasoning` follows how the engine is told to think. llama.cpp makes it
            # an endpoint property, so gemma ships twice: plain (off, speakable
            # latency, fixed-budget JSON) and -think (on, first tokens go to
            # reasoning, so budget content above it). Strata honors reasoning_effort
            # per request, which is the per-model supportsReasoningEffort override
            # below; mergeCompat = {...provider, ...model}, so the llama.cpp models
            # inherit supportsDeveloperRole + sendSessionAffinityHeaders from here.
            #
            # qwen3.8-flash-next-max (the 2-GPU spanning variant) is deliberately
            # absent: the route exists but the variant is gated off on this host's
            # 94 GiB of RAM.
            "mjolnir" = {
              baseUrl = "http://10.0.0.4:8000/v1";
              api = "openai-completions";
              # pi resolves a leading `!command` at runtime (the sops secret file
              # only exists post-activation, so builtins.readFile fails at eval).
              apiKey = "!cat ${config.sops.secrets."litellm-key".path}";
              compat = {
                supportsDeveloperRole = false;
                supportsReasoningEffort = false;
                sendSessionAffinityHeaders = true;
              };
              models = [
                {
                  id = "swift-qwen3.8-27b";
                  reasoning = true;
                  contextWindow = 131072;
                }
                {
                  id = "qwen3.8-flash-next";
                  reasoning = true;
                  contextWindow = 262144;
                  compat = {
                    supportsReasoningEffort = true;
                  };
                }
                # MoE A3B: the cheapest wake on the fleet and 262k of context, at
                # medium reasoning effort (server-side default; the sampler knob
                # does not reach llama.cpp per request).
                {
                  id = "Qwen3.6-35B-A3B";
                  reasoning = true;
                  contextWindow = 262144;
                }
                {
                  id = "gemma-4-26b-a4b";
                  reasoning = false;
                  contextWindow = 131072;
                }
                {
                  id = "gemma-4-26b-a4b-think";
                  reasoning = true;
                  contextWindow = 131072;
                }
              ];
            };
          };
        }
      );

      home.file.".pi/agent/web-search.json".source = lib.mkForce (
        pkgs.writeText "pi-web-search.json" (
          builtins.toJSON {
            provider = "mjolnir";
            model = "qwen3.8-flash-next";
            curator = "none";
          }
        )
      );

      # 64 GB host: Kev-4B instead of the shared 0.8B default (~9 GB weights, ~17 GB load peak).
      services.kev-server = {
        model = "jaredpalmer/kev-4b@139fdd94f1b6a6ad80cc15e08fcb99cac885a101";
        memoryLimitBytes = 20 * 1024 * 1024 * 1024;
        cacheLimitBytes = 1024 * 1024 * 1024;
      };

      programs = {
        ai-agents = {
          pi = {
            config = {
              defaultProvider = "mjolnir";
              # Flash-next as the interactive default (owner call 2026-11-13):
              # 44 tok/s solo, 262k ctx, per-request reasoning effort. The
              # timeout failures were not the model's fault — session timestamps
              # show agents killed mid-progress at exactly 30m. Root causes:
              # turn 1 eats 82s on model wake (on-demand), and contexts with
              # cacheRead=0 grow each turn (199k by turn 10). 60m timeout + 1
              # retry (warm model + warm cache on second attempt) fixes it.
              defaultModel = "mjolnir/qwen3.8-flash-next";
              # 10 min: undici's bodyTimeout/headersTimeout default (300s/5m) is
              # too tight for on-demand wakes. A cold wake is 83-145s, a 200k
              # prefill is ~193s, and queueing behind an in-flight request can
              # add 200s — total ~538s, past the 5m default. 10m covers it
              # without disabling the timeout entirely (the 60m subagent
              # timeoutMs is the real deadline).
              httpIdleTimeoutMs = 600000;
              enabledModels = [
                "mjolnir/swift-qwen3.8-27b"
                "mjolnir/qwen3.8-flash-next"
                "mjolnir/Qwen3.6-35B-A3B"
                "mjolnir/gemma-4-26b-a4b"
                "mjolnir/gemma-4-26b-a4b-think"
              ];
            };
            modelMap = {
              default = "mjolnir/swift-qwen3.8-27b";
              small_model = "mjolnir/qwen3.8-flash-next";
              # Tiered review loop (wiki: decisions/2026-11-13-tiered-review-loop):
              # flash-next is the coder/deep tier (44 tok/s solo, 262k ctx,
              # --batch 2 for concurrent coders — measured faster than sequential
              # because tool I/O overlaps with GPU decode). Fast reviewers run on
              # 35B-A3B (-np 2 slots, 70-98 tok/s per stream). The named reviewer
              # entries below are the deep mapping for manual/PR review via the
              # code-reviewer skill; the orchestrator's wave.js routes in-loop
              # reviewers to the fast-reviewer tier instead.
              coder = "mjolnir/qwen3.8-flash-next";
              fast-reviewer = "mjolnir/Qwen3.6-35B-A3B";
              deep-reviewer = "mjolnir/qwen3.8-flash-next";
              fetcher = "mjolnir/qwen3.8-flash-next";
              plan-critic = "mjolnir/swift-qwen3.8-27b";
              correctness-reviewer = "mjolnir/qwen3.8-flash-next";
              failure-path-reviewer = "mjolnir/qwen3.8-flash-next";
              readability-reviewer = "mjolnir/qwen3.8-flash-next";
              security-reviewer = "mjolnir/qwen3.8-flash-next";
              probe = "mjolnir/qwen3.8-flash-next";
              ticket-auditor = "mjolnir/qwen3.8-flash-next";
              epic-auditor = "mjolnir/swift-qwen3.8-27b";
            };
          };
          skills = {
            # Game development skills
            mattstruble-gamedev = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "gamedev" ];
              include = [
                "game-audio"
                "game-design"
                "game-narrative"
                "game-patterns"
                "game-performance"
                "game-rendering"
                "game-visuals"
                "gpu-rendering-architecture"
                "level-design"
              ];
            };
            mattstruble-love = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "love" ];
              include = [
                "love2d"
                "love2d-fennel"
              ];
            };
            mattstruble-godot = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "godot" ];
              include = [
                "godot"
                "godot-shader"
              ];
            };
            mattstruble-odin = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "odin" ];
              include = [
                "odin-design"
                "odin-gamedev"
              ];
            };
          };
          mcpServers = {
            n8n = {
              type = "remote";
              url = "http://roque:5678/mcp-server/http";
              headers = {
                "Authorization" = "Bearer {file:${config.sops.secrets.n8n-mcp-token.path}}";
              };
              enabled = false;
            };
            fusion = {
              type = "remote";
              url = "http://127.0.0.1:27182/mcp";
              enabled = false;
            };
          };
          opencode = {
            profiles = {
              gamedev.dirs = [ "~/software/gamedev" ];
              odin.dirs = [ "~/software/gamedev/odin" ];
              love.dirs = [ "~/software/gamedev/love2d" ];
              godot.dirs = [ "~/software/gamedev/godot" ];
              infra.dirs = [
                "~/software/infra"
                "~/software/nix-config"
              ];
              ai.dirs = [
                "~/software/ai"
                "~/software/nix-config"
              ];
            };
            config = {
              provider = {
                "mjolnir" = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "Mjolnir llama.cpp (gateway :8000)";
                  options = {
                    baseURL = "http://mjolnir:8000/v1";
                    apiKey = "foo";
                  };
                  models."swift-qwen3.8-27b" = {
                    name = "Swift Qwen3.8-27B (llama.cpp Q4_K_M + MTP)";
                    limit = {
                      context = 131072;
                      output = 8192;
                    };
                  };
                  models."gemma-4-26b-a4b" = {
                    name = "Gemma 4 26B-A4B (llama.cpp UD-Q4_K_XL + MTP)";
                    limit = {
                      context = 131072;
                      output = 8192;
                    };
                  };
                };
              };
              model = "mjolnir/swift-qwen3.8-27b";
              small_model = "mjolnir/gemma-4-26b-a4b";
              agent = {
                planner = {
                  model = "mjolnir/swift-qwen3.8-27b";
                };
                orchestrator = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                coder = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                plan-critic = {
                  model = "mjolnir/swift-qwen3.8-27b";
                };
                correctness-reviewer = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                failure-path-reviewer = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                readability-reviewer = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                security-reviewer = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
                fetcher = {
                  model = "mjolnir/gemma-4-26b-a4b";
                };
              };
            };
          };
        };
        sol-pi = {
          enable = true;
          config = {
            version = 1;
            actionFusion = true;
            observationPack = true;
            # TODO: enable EPR once local reducer model provider is configured
            evidencePreservingReducer = false;
            onlineContextCompact = false;
            cacheWriteReadRatio = 0;
          };
        };
        zen-browser.profiles.default.liveFolders = {
          "Pull requests" = {
            id = "6007b674-05a3-4264-93ec-5d0d8572a14b";
            kind = "github:pull-requests";
            position = 400;
            workspace = "0af700c8-663d-4382-a999-4c4531e997fe";
            github = {
              authorMe = true;
              assignedMe = true;
            };
          };
          "Review requests" = {
            id = "0c3244d2-2bd6-4cc1-bc36-f811473ce054";
            kind = "github:pull-requests";
            position = 401;
            workspace = "0af700c8-663d-4382-a999-4c4531e997fe";
            github.reviewRequested = true;
          };
        };
        git = {
          signing.key = lib.mkForce "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKfEtgBHtXVJsokYWkPFhUkz/U2ZJKk3TO96fNLIZMz";
          settings = {
            user = {
              name = "Matt Struble";
              email = "4325029+mattstruble@users.noreply.github.com";
            };
            github.user = "mattstruble";
          };
        };
        # Pin github.com auth to the mattstruble key (1Password agent selects it by public key).
        ssh.settings."github.com" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519_mattstruble.pub";
          IdentitiesOnly = true;
        };
      };
    };
}
