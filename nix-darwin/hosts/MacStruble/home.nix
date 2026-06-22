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
  "${userName}" = {
    imports = [
      ../../profiles/macos.nix
      ../../home.nix
    ];
    _module.args = {
      ca-bundle_path = ca-bundle_path;
      ca-bundle_crt = ca-bundle_crt;
    };

    services.llm-wiki.remoteUrl = "git@github-llm-wiki:mattstruble/llm-wiki.git";
    programs = {
      ai-agents = {
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
        opencode = {
          profiles = {
            gamedev.dirs = [ "~/software/gamedev" ];
            odin.dirs = [ "~/software/gamedev/odin" ];
            love.dirs = [ "~/software/gamedev/love2d" ];
            godot.dirs = [ "~/software/gamedev/godot" ];
            infra.dirs = [ "~/software/infra" ];
          };
          config = {
            model = "opencode-go/glm-5.2";
            small_model = "opencode-go/deepseek-v4-flash";
            agent = {
              planner = {
                model = "opencode-go/glm-5.2";
              };
              orchestrator = {
                model = "opencode-go/deepseek-v4-pro";
              };
              coder = {
                model = "opencode-go/deepseek-v4-pro";
              };
              plan-critic = {
                model = "opencode-go/glm-5.2";
              };
              correctness-reviewer = {
                model = "opencode-go/deepseek-v4-pro";
              };
              failure-path-reviewer = {
                model = "opencode-go/deepseek-v4-pro";
              };
              readability-reviewer = {
                model = "opencode-go/deepseek-v4-pro";
              };
              security-reviewer = {
                model = "opencode-go/deepseek-v4-pro";
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
