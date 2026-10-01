{
  config,
  lib,
  pkgs,
  ...
}:

# Mergeable JSON settings for the two subagent packages, so hosts add keys
# (e.g. concurrency limits) instead of copying the whole file.
let
  json = pkgs.formats.json { };
  settingsOption =
    file:
    lib.mkOption {
      type = json.type;
      default = { };
      description = "Rendered to ${file}.";
    };
in
{
  options.programs.pi-workflows.settings = settingsOption "~/.pi/workflows/settings.json";
  options.programs.pi-subagents.config = settingsOption "~/.pi/agent/extensions/subagent/config.json";

  config.home.file = {
    ".pi/workflows/settings.json".source =
      json.generate "pi-workflows-settings.json" config.programs.pi-workflows.settings;
    ".pi/agent/extensions/subagent/config.json".source =
      json.generate "pi-subagents-config.json" config.programs.pi-subagents.config;
  };
}
