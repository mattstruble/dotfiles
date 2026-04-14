{ pkgs, inputs, ... }:

let
  workdir = "$HOME/.cache/ebook-mcp";
  ebook-mcp-wrapper = pkgs.writeShellScriptBin "ebook-mcp" ''
    WORK_DIR="${workdir}"
    mkdir -p "$WORK_DIR"

    # Sync source from Nix store into a writable working copy
    ${pkgs.rsync}/bin/rsync -a --delete --chmod=u+w ${inputs.ebook-mcp}/ "$WORK_DIR/src/"

    export UV_PROJECT_ENVIRONMENT="${workdir}/.venv"
    exec ${pkgs.uv}/bin/uv --directory "$WORK_DIR/src" run src/ebook_mcp/main.py
  '';
in
{
  programs.ai-agents.mcpServers."ebook-mcp" = {
    type = "local";
    command = [ "${ebook-mcp-wrapper}/bin/ebook-mcp" ];
    enabled = false;
  };
}
