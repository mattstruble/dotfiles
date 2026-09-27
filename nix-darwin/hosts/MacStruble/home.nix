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
        };
        templates."pi-mcp-json" = {
          content = builtins.toJSON {
            mcpServers = {
              context7 = {
                url = "https://mcp.context7.com/mcp";
              };
              nixos = {
                command = "uvx";
                args = [ "mcp-nixos" ];
              };
              pdf-fast = {
                command = "npx";
                args = [ "@sylphx/pdf-reader-mcp" ];
              };
              n8n = {
                url = "http://roque:5678/mcp-server/http";
                headers = {
                  Authorization = "Bearer ${config.sops.placeholder.n8n-mcp-token}";
                };
              };
            };
          };
          path = "${config.home.homeDirectory}/.pi/agent/mcp.json";
        };
      };

      services.llm-wiki.remoteUrl = "git@github-llm-wiki:mattstruble/llm-wiki.git";

      home.file.".pi/agent/models.json".source = pkgs.writeText "pi-models.json" (
        builtins.toJSON {
          providers = {
            # One provider -> the LiteLLM gateway (:8000). modelName = real running
            # name (pod --alias = gateway model_name). compat is provider-level, with a
            # per-model override for gemma (supportsReasoningEffort -> thinking levels
            # from the API). mergeCompat = {...provider, ...model}, so gemma inherits
            # sendSessionAffinityHeaders + supportsDeveloperRole from the provider.
            "mjolnir" = {
              baseUrl = "http://mjolnir:8000/v1";
              api = "openai-completions";
              apiKey = "foo";
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
                  id = "gemma-4-26b-a4b";
                  reasoning = true;
                  contextWindow = 131072;
                  compat = {
                    supportsReasoningEffort = true;
                  };
                }
              ];
            };
          };
        }
      );

      home.file.".pi/agent/web-search.json".source = lib.mkForce (pkgs.writeText "pi-web-search.json" (
        builtins.toJSON {
          provider = "mjolnir";
          model = "gemma-4-26b-a4b";
          curator = "none";
        }
      ));

      programs = {
        ai-agents = {
          pi = {
            config = {
              defaultProvider = "mjolnir";
              defaultModel = "mjolnir/swift-qwen3.8-27b";
              enabledModels = [
                "mjolnir/swift-qwen3.8-27b"
                "mjolnir/gemma-4-26b-a4b"
              ];
            };
            modelMap = {
              default = "mjolnir/swift-qwen3.8-27b";
              small_model = "mjolnir/gemma-4-26b-a4b";
              planner = "mjolnir/swift-qwen3.8-27b";
              orchestrator = "mjolnir/swift-qwen3.8-27b";
              builder = "mjolnir/gemma-4-26b-a4b";
              coder = "mjolnir/gemma-4-26b-a4b";
              fetcher = "mjolnir/gemma-4-26b-a4b";
              plan-critic = "mjolnir/swift-qwen3.8-27b";
              correctness-reviewer = "mjolnir/gemma-4-26b-a4b";
              failure-path-reviewer = "mjolnir/gemma-4-26b-a4b";
              readability-reviewer = "mjolnir/gemma-4-26b-a4b";
              security-reviewer = "mjolnir/gemma-4-26b-a4b";
            };
          };
          skills = {
            # Game development skills
            mattstruble-ai = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "ai" ];
              include = [
                "agent-architecture"
                "agent-evaluation"
                "agent-memory"
                "agent-post-training"
                "agent-self-evolution"
                "agent-tool-design"
                "context-engineering"
                "ml-post-training"
                "multi-agent-collaboration"
                "rag-design"
              ];
            };
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
            # Infra skills
            mattstruble-infra = {
              source = inputs.skills-mattstruble;
              priority = 200;
              profiles = [ "infra" ];
              include = [
                "grafana"
                "helm"
                "homelab-monitoring"
                "k3s"
                "k8s-networking"
                "k8s-operations"
                "k8s-storage"
                "k8s-workloads"
                "logql"
                "promql"
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
              infra.dirs = [ "~/software/infra" ];
              ai.dirs = [ "~/software/ai" ];
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
          settings = {
            user = {
              name = "Matt Struble";
              email = "4325029+mattstruble@users.noreply.github.com";
            };
            github.user = "mattstruble";
          };
        };
      };
    };
}
