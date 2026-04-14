{ pkgs, ... }:

let
  pdf-visual-wrapper = pkgs.writeShellScriptBin "pdf-visual" ''
    exec ${pkgs.uv}/bin/uvx --from "git+https://github.com/I-CAN-hack/pdf-mcp.git" pdf-mcp "$@"
  '';
in
{
  programs.ai-agents.mcpServers."pdf-visual" = {
    type = "local";
    command = [ "${pdf-visual-wrapper}/bin/pdf-visual" ];
    enabled = false;
  };
}
