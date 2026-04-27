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
            plugin = [ "opencode-claude-auth@latest" ];
            model = "anthropic/claude-sonnet-4-5-20250929";
            agent = {
              orchestrator = {
                model = "anthropic/claude-sonnet-4-5-20250929";
              };
              coder = {
                model = "anthropic/claude-sonnet-4-5-20250929";
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
