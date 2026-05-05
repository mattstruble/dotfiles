{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  wikiPath = "${homeDir}/llm-wiki";
in {
  home.activation.ensureLlmWiki = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${wikiPath}" ]; then
      mkdir -p "${wikiPath}"
    fi
    if [ ! -d "${wikiPath}/.git" ]; then
      ${pkgs.git}/bin/git -C "${wikiPath}" init
    fi
  '';

  launchd.agents.llm-wiki-sync = {
    enable = true;
    config = {
      Label = "com.user.llm-wiki-sync";
      ProgramArguments = [
        "${pkgs.bash}/bin/bash" "-c" ''
          cd "${wikiPath}" || exit 0
          [ -d .git ] || exit 0
          [ -n "$(${pkgs.git}/bin/git status --porcelain)" ] || exit 0
          ${pkgs.git}/bin/git add -A
          ${pkgs.git}/bin/git commit -m "auto-sync: $(date -Iseconds)"
          if [ -n "$(${pkgs.git}/bin/git remote)" ]; then
            ${pkgs.git}/bin/git push || true
          fi
        ''
      ];
      StartInterval = 1800;
    };
  };
}
