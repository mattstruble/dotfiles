{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  wikiPath = "${homeDir}/llm-wiki";
  keyPath = "${homeDir}/.ssh/llm_wiki_deploy";
  remoteUrl = "git@github-llm-wiki:mstruble-lila/llm-wiki.git";
in {
  home.activation.ensureLlmWiki = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Generate deploy key if it doesn't exist
    if [ ! -f "${keyPath}" ]; then
      mkdir -p "$(dirname "${keyPath}")"
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "${keyPath}" -N "" -C "llm-wiki-deploy"
      echo "==> llm-wiki deploy key generated. Add this public key to GitHub:"
      cat "${keyPath}.pub"
    fi

    # Ensure repo exists
    if [ ! -d "${wikiPath}" ]; then
      mkdir -p "${wikiPath}"
    fi
    if [ ! -d "${wikiPath}/.git" ]; then
      ${pkgs.git}/bin/git -C "${wikiPath}" init
    fi

    # Set remote to use the deploy-key host alias
    CURRENT_REMOTE=$(${pkgs.git}/bin/git -C "${wikiPath}" remote get-url origin 2>/dev/null || echo "")
    if [ -z "$CURRENT_REMOTE" ]; then
      ${pkgs.git}/bin/git -C "${wikiPath}" remote add origin "${remoteUrl}"
    elif [ "$CURRENT_REMOTE" != "${remoteUrl}" ]; then
      ${pkgs.git}/bin/git -C "${wikiPath}" remote set-url origin "${remoteUrl}"
    fi

    # Disable commit signing (avoid 1Password prompt in background agent)
    ${pkgs.git}/bin/git -C "${wikiPath}" config commit.gpgsign false
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
