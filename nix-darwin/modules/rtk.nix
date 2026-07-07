{ config, lib, inputs, ... }:

let
  cfg = config.programs.rtk;
in {
  options.programs.rtk = {
    enable = lib.mkEnableOption "RTK token-saving proxy plugin for opencode";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."opencode/plugins/rtk.ts".source =
      "${inputs.rtk}/hooks/opencode/rtk.ts";

    programs.ai-agents.opencode.config.permission.bash."rtk *" = "allow";
  };
}
