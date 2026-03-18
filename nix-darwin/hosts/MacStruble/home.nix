let
  userName = import ./username.nix;
  ca-bundle_path = "/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-certificates.crt";
in
{
  "${userName}" = {
    imports = [
      ../../profiles/macos.nix
      ../../home.nix
    ];
    _module.args = {
      ca-bundle_path = ca-bundle_path;
      ca-bundle_crt = ca-bundle_crt;
    };
    programs = {
      ai-agents = {
        opencode = {
          config = {
            model = "anthropic/claude-sonnet-4-5-20250929";
            provider = {
              ollama = {
                npm = "@ai-sdk/openai-compatible";
                name = "Ollama (local)";
                options = {
                  baseURL = "http://localhost:11434/v1";
                };
                models = {
                  "qwen2.5-coder:14b" = {
                    name = "Qwen 2.5 Coder 14B";
                    limit = {
                      context = 32768;
                      output = 8192;
                    };
                  };
                  "qwen2.5:7b" = {
                    name = "Qwen 2.5 7B";
                    limit = {
                      context = 32768;
                      output = 8192;
                    };
                  };
                };
              };
            };
            agent = {
              orchestrator = {
                model = "anthropic/claude-sonnet-4-5-20250929";
              };
              coder = {
                model = "anthropic/claude-sonnet-4-5-20250929";
              };
              pr-reviewer = {
                model = "ollama/qwen2.5-coder:14b";
              };
              security = {
                model = "anthropic/claude-sonnet-4-5-20250929";
              };
              fetcher = {
                model = "ollama/qwen2.5:7b";
              };
            };
          };
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
