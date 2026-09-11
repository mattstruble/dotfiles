{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sol-pi;
  piEnabled = config.programs.ai-agents.enable && builtins.elem "pi" config.programs.ai-agents.agents;

  # builtins.toJSON produces compact JSON; reformat with jq for 2-space indent
  prettyJson = let
    rawJson = pkgs.writeText "sol-pi-raw.json" (builtins.toJSON cfg.config);
  in pkgs.runCommand "sol-pi.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq --indent 2 '.' ${rawJson} > $out
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
