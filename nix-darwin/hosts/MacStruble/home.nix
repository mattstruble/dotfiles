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

      programs = {
        ai-agents = {
          pi = {
            config = {
              defaultProvider = "opencode-go";
              defaultModel = "opencode-go/glm-5.2";
              enabledModels = [
                "opencode-go/glm-5.2"
                "opencode-go/deepseek-v4-flash-free"
                "mjolnir-qwen38/qwen3.8-27b"
                "mjolnir-llama/Qwen3.6-35B-A3B-UD-Q4_K_XL"
              ];
            };
            auth = {
              "mjolnir-qwen38" = {
                type = "api_key";
                key = "foo";
                env = {
                  OPENAI_BASE_URL = "http://mjolnir:8556/v1";
                };
              };
              "mjolnir-llama" = {
                type = "api_key";
                key = "foo";
                env = {
                  OPENAI_BASE_URL = "http://mjolnir:8555/v1";
                };
              };
            };
            modelMap = {
              default = "opencode-go/glm-5.2";
              small_model = "opencode-go/deepseek-v4-flash-free";
              planner = "opencode-go/glm-5.2";
              orchestrator = "opencode-go/glm-5.2";
              builder = "opencode/deepseek-v4-flash";
              coder = "opencode/deepseek-v4-flash";
              fetcher = "opencode-go/deepseek-v4-flash-free";
              plan-critic = "opencode-go/glm-5.2";
              correctness-reviewer = "opencode/deepseek-v4-flash";
              failure-path-reviewer = "opencode/deepseek-v4-flash";
              readability-reviewer = "opencode/deepseek-v4-flash";
              security-reviewer = "opencode/deepseek-v4-flash";
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
                "mjolnir-qwen38" = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "Mjolnir llama.cpp (Qwen3.8-27B Q4 + MTP)";
                  options = {
                    baseURL = "http://mjolnir:8556/v1";
                    apiKey = "foo";
                  };
                  models."qwen3.8-27b" = {
                    name = "Qwen3.8-27B (llama.cpp UD-Q4_K_XL)";
                    limit = {
                      context = 16384;
                      output = 8192;
                    };
                  };
                };
                "mjolnir-llama" = {
                  npm = "@ai-sdk/openai-compatible";
                  name = "Mjolnir llama.cpp (Qwen3.6-35B-A3B)";
                  options = {
                    baseURL = "http://mjolnir:8555/v1";
                    apiKey = "foo";
                  };
                  models."Qwen3.6-35B-A3B-UD-Q4_K_XL" = {
                    name = "Qwen3.6-35B-A3B MoE";
                    limit = {
                      context = 32768;
                      output = 32768;
                    };
                  };
                };
              };
              model = "opencode-go/glm-5.2";
              small_model = "opencode-go/deepseek-v4-flash-free";
              agent = {
                planner = {
                  model = "opencode-go/glm-5.2";
                };
                orchestrator = {
                  model = "opencode/deepseek-v4-flash";
                };
                coder = {
                  model = "opencode/deepseek-v4-flash";
                };
                plan-critic = {
                  model = "opencode-go/glm-5.2";
                };
                correctness-reviewer = {
                  model = "opencode/deepseek-v4-flash";
                };
                failure-path-reviewer = {
                  model = "opencode/deepseek-v4-flash";
                };
                readability-reviewer = {
                  model = "opencode/deepseek-v4-flash";
                };
                security-reviewer = {
                  model = "opencode/deepseek-v4-flash";
                };
                fetcher = {
                  model = "opencode/deepseek-v4-flash-free";
                };
              };
            };
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
