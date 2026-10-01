{
  config,
  lib,
  pkgs,
  ...
}:

let
  json = pkgs.formats.json { };
in
{
  options.programs.pi-mcp.servers = lib.mkOption {
    type = lib.types.attrsOf json.type;
    default = { };
    description = "Servers for pi's built-in MCP support, rendered to ~/.pi/agent/mcp.json.";
  };

  # mcp.json is a read-only nix store symlink: use /mcp only to inspect and log in.
  # Exposure/enabled toggles and `pi mcp add` can't persist; change servers here.
  config.home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
    mcpServers = config.programs.pi-mcp.servers;
  };
}
