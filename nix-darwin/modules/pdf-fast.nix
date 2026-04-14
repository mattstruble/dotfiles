{ pkgs, ... }:

let
  pdf-fast-wrapper = pkgs.writeShellScriptBin "pdf-fast" ''
    exec ${pkgs.nodejs}/bin/npx @sylphx/pdf-reader-mcp "$@"
  '';
in
{
  programs.ai-agents.mcpServers."pdf-fast" = {
    type = "local";
    command = [ "${pdf-fast-wrapper}/bin/pdf-fast" ];
    enabled = false;
  };
}
