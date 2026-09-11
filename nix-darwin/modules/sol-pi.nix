{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sol-pi;
  piEnabled = config.programs.ai-agents.enable && builtins.elem "pi" config.programs.ai-agents.agents;

  # builtins.toJSON produces compact JSON; reformat with jq for 2-space indent
  prettyJson = pkgs.runCommand "sol-pi.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    echo '${builtins.toJSON cfg.config}' | jq --indent 2 '.' > $out
  '';
in
{
  options.programs.sol-pi = {
    enable = lib.mkEnableOption "SoL-Pi agent configuration";

    config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Attribute set written as ~/.pi/agent/sol-pi.json";
    };
  };

  config = lib.mkIf (cfg.enable && piEnabled && cfg.config != { }) {
    home.file.".pi/agent/sol-pi.json".source = prettyJson;
  };
}
