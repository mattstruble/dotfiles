{ config, lib, ... }:

let
  cfg = config.programs.finicky;
in
{
  options.programs.finicky = {
    enable = lib.mkEnableOption "Finicky link routing (app installed via the finicky Homebrew cask)";

    defaultBrowser = lib.mkOption {
      type = lib.types.str;
      default = "app.zen-browser.zen";
      description = "App name or bundle ID that opens links no app rule claims.";
    };

    apps = lib.mkOption {
      # Rules open the app with `open -b`, which fails when it is not installed,
      # so enable only apps present on the host.
      type = lib.types.listOf (
        lib.types.enum [
          "figma"
          "notion"
          "slack"
          "spotify"
          "teams"
          "zoom"
        ]
      );
      default = [ ];
      description = "Apps whose web links open in the desktop app instead of the browser.";
    };

    slackTeams = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        acme = "T0123456";
        "acme.enterprise" = "E0123456";
      };
      description = ''
        Slack subdomain (the part before .slack.com) to team or Enterprise Grid org ID,
        needed to deep-link <subdomain>.slack.com/archives/... links.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."finicky/finicky.js".text = ''
      const settings = ${
        builtins.toJSON { inherit (cfg) defaultBrowser apps slackTeams; }
      };

      ${builtins.readFile ./finicky/finicky.js}
    '';
  };
}
