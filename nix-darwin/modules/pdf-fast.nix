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

  programs.pi-mcp.servers.pdf-fast = {
    command = "${pdf-fast-wrapper}/bin/pdf-fast";
    sandbox.launcher = "npx";
    description = "Read text, metadata, and images from local PDF files.";
  };
}
