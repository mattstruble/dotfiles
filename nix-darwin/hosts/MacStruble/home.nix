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
            model = "opencode-go/glm-5.1";
            small_model = "opencode-go/deepseek-v4-flash";
            agent = {
              orchestrator = {
                model = "opencode-go/glm-5.1";
              };
              coder = {
                model = "opencode-go/deepseek-v4-pro";
              };
              correctness-reviewer = {
                model = "opencode-go/qwen3.6-plus";
              };
              failure-path-reviewer = {
                model = "opencode-go/qwen3.6-plus";
              };
              readability-reviewer = {
                model = "opencode-go/qwen3.6-plus";
              };
              security-reviewer = {
                model = "opencode-go/qwen3.6-plus";
              };
              fetcher = {
                model = "opencode-go/deepseek-v4-flash";
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
