{
  pkgs,
  lib,
  config,
  hostname,
  inputs,
  ca-bundle_path ? "${pkgs.cacert}/etc/ssl/certs",
  ca-bundle_crt ? "${ca-bundle_path}/ca-bundle.crt",
  ...
}:

let
  tmpdir = "/tmp";
  userName = import ./hosts/${hostname}/username.nix;
  home = "/Users/${userName}";
  path = "${home}/dotfiles";
  onePassPath = "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  brew_path = "/opt/homebrew/bin";
in
{
  home = {
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;

    packages = import ./packages.nix pkgs ++ import ./hosts/${hostname}/packages.nix pkgs;

    sessionVariables = {
      FONTCONFIG_FILE = "${config.xdg.configHome}/fontconfig/fonts.conf";
      FONTCONFIG_PATH = "${config.xdg.configHome}/fontconfig";
      GNUPGHOME = "${config.xdg.configHome}/gnupg";
      JAVA_OPTS = "-Xverify:none";
      LESSHISTFILE = "${config.xdg.cacheHome}/less/history";
      VAGRANT_HOME = "${config.xdg.dataHome}/vagrant";
      TZ = "America/New_York";
      EDITOR = "nvim";
      XDG_CONFIG_HOME = "${config.xdg.configHome}";

      VAGRANT_DEFAULT_PROVIDER = "vmware_desktop";
      VAGRANT_VMWARE_CLONE_DIRECTORY = "${home}/Machines/vagrant";
      FILTER_BRANCH_SQUELCH_WARNING = "1";

      AWS_CA_BUNDLE = "${ca-bundle_crt}";
      REQUESTS_CA_BUNDLE = "${ca-bundle_crt}";
      NODE_EXTRA_CA_CERTS = "${ca-bundle_crt}";
      SSL_CERT_FILE = "${ca-bundle_crt}";
      CURL_CA_BUNDLE = "${ca-bundle_crt}";
      PIP_CERT = "${ca-bundle_crt}";

      MANPATH = lib.concatStringsSep ":" [
        "${home}/.nix-profile/share/man"
        "/run/current-system/sw/share/man"
        "/usr/local/share/man"
        "/usr/share/man"
      ];

    };

    sessionPath = [
      "/usr/local/bin"
      "/usr/local/zfs/bin"
      "${brew_path}"
    ];

    file =
      let
        mkLink = config.lib.file.mkOutOfStoreSymlink;
      in
      {
        ".curlrc".text = ''
          capath=${ca-bundle_path}
          cacert=${ca-bundle_crt}
        '';

        ".wgetrc".text = ''
          ca_directory = ${ca-bundle_path}
          ca_certificate = ${ca-bundle_crt}
        '';

        ".direnvrc".source = mkLink "${path}/direnv/.direnvrc";
        ".p10k.zsh".source = mkLink "${path}/p10k/.p10k.zsh";

        ".local/bin/vim_opener".source = mkLink "${path}/commands/.local/bin/vim_opener";
        ".local/bin/um".source = mkLink "${path}/commands/.local/bin/um";

        # Ponytail: expose full repo so plugin's relative requires resolve
        ".local/share/ponytail".source = inputs.ponytail;
      };

    activation.setupDockerCliPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DOCKER_CONFIG="$HOME/.docker"
      DOCKER_CLI_PLUGINS="$DOCKER_CONFIG/cli-plugins"
      DOCKER_CONFIG_JSON="$DOCKER_CONFIG/config.json"
      BREW_PLUGINS="/opt/homebrew/lib/docker/cli-plugins"

      # Remove stale symlinks in ~/.docker/cli-plugins/ (e.g., leftover Docker Desktop links)
      if [ -d "$DOCKER_CLI_PLUGINS" ]; then
        find "$DOCKER_CLI_PLUGINS" -maxdepth 1 -type l ! -exec test -e {} \; -delete
      fi

      # Ensure ~/.docker/config.json includes cliPluginsExtraDirs for Homebrew plugins
      if [ -f "$DOCKER_CONFIG_JSON" ]; then
        EXISTING=$(${pkgs.jq}/bin/jq -r '.cliPluginsExtraDirs // [] | join(",")' "$DOCKER_CONFIG_JSON" 2>/dev/null || echo "")
        if ! echo "$EXISTING" | grep -q "$BREW_PLUGINS"; then
          ${pkgs.jq}/bin/jq --arg dir "$BREW_PLUGINS" '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$dir] | unique)' \
            "$DOCKER_CONFIG_JSON" > "$DOCKER_CONFIG_JSON.tmp" && mv "$DOCKER_CONFIG_JSON.tmp" "$DOCKER_CONFIG_JSON"
        fi
      else
        mkdir -p "$DOCKER_CONFIG"
        echo '{"cliPluginsExtraDirs": ["'"$BREW_PLUGINS"'"]}' | ${pkgs.jq}/bin/jq . > "$DOCKER_CONFIG_JSON"
      fi
    '';

    activation.seedFortuneCow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      FORTUNE_COW_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/fortune-cow"
      mkdir -p "$(dirname "$FORTUNE_COW_CACHE")"
      ${pkgs.fortune}/bin/fortune -a fortunes wisdom | ${pkgs.cowsay}/bin/cowsay > "$FORTUNE_COW_CACHE.tmp" && \
        mv "$FORTUNE_COW_CACHE.tmp" "$FORTUNE_COW_CACHE"
    '';

    activation.umCompletion = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cacheDir="''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
      mkdir -p "$cacheDir"
      if [ -x "$HOME/.local/bin/um" ]; then
        "$HOME/.local/bin/um" --completion > "$cacheDir/um-completion.zsh.tmp" 2>/dev/null \
          && mv "$cacheDir/um-completion.zsh.tmp" "$cacheDir/um-completion.zsh" \
          || rm -f "$cacheDir/um-completion.zsh.tmp"
      fi
      true
    '';
  };

  xdg.configFile =
    let
      mkLink = config.lib.file.mkOutOfStoreSymlink;
    in
    {
      "aerospace".source = mkLink "${path}/aerospace/.config/aerospace";
      "kitty".source = mkLink "${path}/kitty/.config/kitty";
      "harper-ls".source = mkLink "${path}/harper-ls/.config/harper-ls";
      "lazygit".source = mkLink "${path}/lazygit/.config/lazygit";
      "nvim".source = mkLink "${path}/nvim/.config/nvim";

      "python_keyring/keyringrc.cfg".text = ''
        [backend]
        default-keyring=keyring.backends.macOS.Keyring
      '';
      "sketchybar".source = mkLink "${path}/sketchybar/.config/sketchybar";
      "tmux".source = mkLink "${path}/tmux/.config/tmux";
      "yamlfmt".source = mkLink "${path}/yamlfmt/.config/yamlfmt";

      "opencode/tui.json".source = mkLink "${path}/opencode/.config/opencode/tui.json";
      "opencode/themes".source = mkLink "${path}/opencode/.config/opencode/themes";

      # Ponytail: plugin (auto-discovered from plugins/ dir)
      "opencode/plugins/ponytail.mjs".source = mkLink "${home}/.local/share/ponytail/.opencode/plugins/ponytail.mjs";

      # Ponytail: slash commands
      "opencode/commands/ponytail.md".source = mkLink "${home}/.local/share/ponytail/.opencode/command/ponytail.md";
      "opencode/commands/ponytail-review.md".source = mkLink "${home}/.local/share/ponytail/.opencode/command/ponytail-review.md";
      "opencode/commands/ponytail-audit.md".source = mkLink "${home}/.local/share/ponytail/.opencode/command/ponytail-audit.md";
      "opencode/commands/ponytail-debt.md".source = mkLink "${home}/.local/share/ponytail/.opencode/command/ponytail-debt.md";

      # Beads: automatic bd prime injection plugin
      "opencode/plugins/beads.mjs".source = mkLink "${path}/opencode/.config/opencode/plugins/beads.mjs";

      # Knowledge base: auto-inject ~/llm-wiki/INDEX.md and commit on idle
      "opencode/plugins/knowledge-base.mjs".source = mkLink "${path}/opencode/.config/opencode/plugins/knowledge-base.mjs";

      "gnupg/gpg-agent.conf".text = ''
        enable-ssh-support
        default-cache-ttl 86400
        max-cache-ttl 86400
        pinentry-program ${pkgs.pinentry_mac}/Applications/pinentry-mac.app/Contents/MacOS/pinentry-mac
      '';

      "aspell/config".text = ''
        local-data-dir ${pkgs.aspell}/lib/aspell
        data-dir ${pkgs.aspellDicts.en}/lib/aspell
        personal ${config.xdg.configHome}/aspell/en_US.personal
        repl ${config.xdg.configHome}/aspell/en_US.repl
      '';
    };

  imports = [
    inputs.ai-agents.homeManagerModules.default
    inputs.agent-sandbox.homeManagerModules.default
    ./modules/ebook-mcp.nix
    ./modules/llm-wiki.nix
    ./modules/neovim-treesitter.nix
    ./modules/pdf-fast.nix
    ./modules/pdf-visual.nix
  ];

  programs = {

    ai-agents = {
      enable = true;
      agents = [
        "opencode"
        "claude"
      ];
      subagents = [
        "${path}/opencode/.config/opencode/agents/"
      ];
      skills = {
        mattstruble = {
          source = inputs.skills-mattstruble;
          priority = 200;
        };
      };

      mcpServers = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
        slack = {
          type = "local";
          command = [
            "npx"
            "-y"
            "slack-mcp-server@latest"
            "--transport"
            "stdio"
          ];
          enabled = false;
        };
        nixos = {
          type = "local";
          command = [ "mcp-nixos" ];
          enabled = false;
        };
      };

      opencode = {
        agentsFile = config.lib.file.mkOutOfStoreSymlink "${path}/opencode/.config/opencode/AGENTS.md";
        config = {
          "$schema" = "https://opencode.ai/config.json";
          autoupdate = false;
          agent = {
            orchestrator = {
              tools = {
                "github*" = true;
              };
            };
            fetcher = {
              tools = {
                "context7*" = true;
              };
            };
          };
          permission = {
            external_directory = {
              "/tmp/opencode-wt/**" = "allow";
              "/private/tmp/opencode-wt/**" = "allow";
              "~/.opencode/**" = "allow";
              "~/.beads-planning/**" = "allow";
              "~/llm-wiki/**" = "allow";
            };
            bash = {
              # Default: prompt for all commands
              "*" = "ask";

              # --- File inspection ---
              "cat *" = "allow";
              "cd /tmp/opencode-wt/*" = "allow";
              "cd /private/tmp/opencode-wt/*" = "allow";
              "file *" = "allow";
              "head *" = "allow";
              "ls *" = "allow";
              "echo *" = "allow";
              "sort *" = "allow";
              "md5sum *" = "allow";
              "sha256sum *" = "allow";
              "stat *" = "allow";
              "tail *" = "allow";
              "wc *" = "allow";
              "mkdir ~/.opencode/*" = "allow";
              "mkdir -p ~/.opencode/*" = "allow";

              # --- Search ---
              "find *" = "allow";
              "grep *" = "allow";
              "rg *" = "allow";
              "which *" = "allow";

              # --- Git: allow read-only, ask for state-changing ---
              "git *" = "allow";
              "git worktree *" = "allow"; # explicit for documentation (redundant with "git *")
              "git add *" = "ask";
              "git checkout *" = "ask";
              "git cherry-pick *" = "ask";
              "git clean *" = "ask";
              "git commit *" = "ask";
              "git merge *" = "ask";
              "git mv *" = "ask";
              "git pull *" = "ask";
              "git push *" = "ask";
              "git rebase *" = "ask";
              "git reset *" = "ask";
              "git restore *" = "ask";
              "git revert *" = "ask";
              "git rm *" = "ask";
              "git stash *" = "ask";
              "git switch *" = "ask";
              "git tag *" = "ask";

              # --- Beads issue tracking ---
              "bd *" = "allow";

              # --- Python read-only ---
              "pip list *" = "allow";
              "pip show *" = "allow";
              "python --version" = "allow";
              "python3 --version" = "allow";
              "uv --version" = "allow";
              "uv pip list *" = "allow";
              "uv pip show *" = "allow";
              "uv tree *" = "allow";
              "uv python list *" = "allow";
              "uv version *" = "allow";
              "uv run pytest *" = "allow";
              "uv run coverage *" = "allow";
              "uv run ruff *" = "allow";
              "uv run mypy *" = "allow";
              "uv run pyright *" = "allow";
              "uv run bandit *" = "allow";
              "uv run pre-commit *" = "allow";

              # --- Nix read-only ---
              "nix eval *" = "allow";
              "nix flake metadata *" = "allow";
              "nix flake show *" = "allow";
              "nix-store --query *" = "allow";
              "nix-store -q *" = "allow";

              # --- Docker read-only ---
              "docker images *" = "allow";
              "docker info" = "allow";
              "docker inspect *" = "allow";
              "docker logs *" = "allow";
              "docker ps *" = "allow";
              "docker version" = "allow";

              # --- Build tools (read-only) ---
              "cargo check *" = "allow";
              "go vet *" = "allow";
              "make --dry-run *" = "allow";
              "make -n *" = "allow";
            };
            edit = "allow";
            glob = "allow";
            grep = "allow";
            list = "allow";
            task = "allow";
            skill = "allow";
            lsp = "allow";
            read = "allow";
            webfetch = "allow";
          };
        };
      };
    };

    agent-sandbox = {
      enable = true;
      package = inputs.agent-sandbox.packages.${pkgs.system}.default;
      settings.mounts.extraPaths = [
        "~/llm-wiki"
      ];
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    htop.enable = true;
    info.enable = true;
    jq.enable = true;
    man.enable = true;
    vim.enable = true;

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      options = [ "--cmd cd" ];
    };

    home-manager = {
      enable = true;
    };

    # firefox = {
    #   enable = true;
    #   profiles.myprofile.settings = inputs.arkenfox-userjs.lib.userjs // {
    #     # your overrides here, e.g.
    #   };
    # };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--info=inline"
        "--border"
        "--exact"
      ];
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetOptions = [
        "--preview '${pkgs.bat}/bin/bat -n --color=always --line-range :500 {}'"
      ];
    };

    bash = {
      enable = true;
      bashrcExtra = lib.mkBefore ''
        source /etc/bashrc
      '';
    };

    gpg = {
      enable = true;
      homedir = "${config.xdg.configHome}/gnupg";
    };

    gh = {
      enable = true;
      settings = {
        editor = "nvim";
        git_protocol = "ssh";
        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
    };

    git = {
      enable = true;
      package = pkgs.gitMinimal;

      ignores = [
        "*~"
        "*.swp"
        ".DS_Store"
        "*.LSOverride"
        "*.null-ls*"
        ".direnv"
        ".envrc"
        "Thumbs.db"
        ".bundle"
      ];

      signing = {
        format = "ssh";
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEM+saqSDNRJt5qpi6lltteSsdY7wNVz5Is2ywVFcyzv";
        signByDefault = true;
        signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };

      lfs = {
        enable = true;
        skipSmudge = true;
      };

      settings = {

        alias = {
          amend = "commit --amend -C HEAD";
          authors =
            "!\"${pkgs.git}/bin/git log --pretty=format:%aN"
            + " | ${pkgs.coreutils}/bin/sort"
            + " | ${pkgs.coreutils}/bin/uniq -c"
            + " | ${pkgs.coreutils}/bin/sort -rn\"";
          b = "branch --color -v";
          ca = "commit --amend";
          changes = "diff --name-status -r";
          co = "checkout";
          cp = "cherry-pick";
          dc = "diff --cached";
          dh = "diff HEAD";
          ds = "diff --staged";
          from = "!${pkgs.git}/bin/git bisect start && ${pkgs.git}/bin/git bisect bad HEAD && ${pkgs.git}/bin/git bisect good";
          ls-ignored = "ls-files --exclude-standard --ignored --others";
          mt = "mergetool";
          rc = "rebase --continue";
          rh = "reset --hard";
          ri = "rebase --interactive";
          rs = "rebase --skip";
          ru = "remote update --prune";
          snap = "!${pkgs.git}/bin/git stash" + " && ${pkgs.git}/bin/git stash apply";
          snaplog =
            "!${pkgs.git}/bin/git log refs/snapshots/refs/heads/" + "\$(${pkgs.git}/bin/git rev-parse HEAD)";
          spull =
            "!${pkgs.git}/bin/git stash" + " && ${pkgs.git}/bin/git pull" + " && ${pkgs.git}/bin/git stash pop";
          su = "submodule update --init --recursive";
          undo = "reset --soft HEAD^";
          kd = "difftool --no-symlinks --dir-diff";
          w = "status -sb";
          wdiff = "diff --color-words";
          l =
            "log --graph --pretty=format:'%Cred%h%Creset"
            + " —%Cblue%d%Creset %s %Cgreen(%cr)%Creset'"
            + " --abbrev-commit --date=relative --show-notes=*";
          # List and remove untracked remote repositories
          # https://stackoverflow.com/a/17029936
          untracked = "!${pkgs.git}/bin/git fetch --prune && ${pkgs.git}/bin/git branch -r | awk '{print \$1}' | egrep -v -f /dev/fd/0 <(${pkgs.git}/bin/git branch -vv | grep origin) | awk '{print \$1}'";
          remove-untracked = "!${pkgs.git}/bin/git fetch --prune && ${pkgs.git}/bin/git branch -r | awk '{print \$1}' | egrep -v -f /dev/fd/0 <(${pkgs.git}/bin/git branch -vv | grep origin) | awk '{print \$1}' | xargs ${pkgs.git}/bin/git branch -d";
        };

        core = {
          editor = "nvim";
          trustctime = false;
          pager = "${pkgs.less}/bin/less --tabs=4 -RFX";
          logAllRefUpdates = true;
          precomposeunicode = false;
          whitespace = "trailing-space,space-before-tab";
          autocrlf = "input";
        };

        branch.autosetupmerge = true;
        commit.status = false;
        credential.helper = "store";
        mergetool.keepBackup = false;
        pull.rebase = true;
        rebase.autosquash = true;
        rerere.enabled = true;
        init.defaultBranch = "main";

        "merge \"ours\"".driver = true;

        http = {
          sslCAinfo = ca-bundle_crt;
          sslverify = true;
        };

        color = {
          status = "auto";
          diff = "auto";
          branch = "auto";
          interactive = "auto";
          ui = "auto";
          sh = "auto";
        };

        push = {
          default = "simple";
          gpgsign = "if-asked";
          autoSetupRemote = true;
          recurseSubmodules = "no";
        };

        merge = {
          conflictstyle = "diff3";
          stat = true;
          tool = "nvimdiff";
        };

        "color \"sh\"" = {
          branch = "yellow reverse";
          workdir = "blue bold";
          dirty = "red";
          dirty-stash = "red";
          repo-state = "red";
        };

        annex = {
          backends = "BLAKE2B512E";
          alwayscommit = false;
        };

        submodule = {
          recurse = true;
        };

        diff = {
          ignoreSubmodules = "dirty";
          renames = "copies";
          mnemonicprefix = true;
          tool = "kitty";
          guitool = "kitty.gui";
        };

        difftool = {
          prompt = false;
          trustExitCode = true;
        };

        "difftool \"kitty\"" = {
          cmd = "kitten diff $LOCAL $REMOTE";
        };

        "difftool \"kitty.gui\"" = {
          cmd = "kitten diff $LOCAL $REMOTE";
        };

        "mergetool \"nvimdiff\"" = {
          layout = "LOCAL,BASE,REMOTE / MERGED";
        };

        advice = {
          statusHints = false;
          pushNonFastForward = false;
          objectNameWarning = "false";
        };

      };

    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "github-llm-wiki" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = "~/.ssh/llm_wiki_deploy";
          IdentitiesOnly = true;
          IdentityAgent = "none";
        };

        "*" = {
          Compression = true;
          AddKeysToAgent = "yes";
          ControlMaster = "auto";
          ControlPath = "${tmpdir}/ssh-%u-%r@%h:%p";
          ControlPersist = "no";

          ForwardAgent = true;
          ServerAliveInterval = 60;

          HashKnownHosts = true;
          UserKnownHostsFile = "${home}/.ssh/known_hosts";
          IdentityAgent = "${onePassPath}";
        };
      };
    };

    zsh = {
      dotDir = "${config.xdg.configHome}/zsh";

      enable = true;
      enableCompletion = false;
      autocd = true;
      setOptions = [
        "NO_BEEP"
        "NUMERIC_GLOB_SORT"
      ];

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 50000;
        save = 500000;
        path = "${config.xdg.configHome}/zsh/history";
        ignoreDups = true;
        share = true;
        extended = true;
        ignoreSpace = true;
        expireDuplicatesFirst = true;
        findNoDups = true;
      };

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        ALTERNATE_EDITOR = "${pkgs.vim}/bin/vi";
        LC_CTYPE = "en_US.UTF-8";
        LEDGER_COLOR = "true";
        LESS = "-FRSXM";
        LESSCHARSET = "utf-8";
        PAGER = "less";
        MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
        SSH_AUTH_SOCK = "${onePassPath}";
        TINC_USE_NIX = "yes";
        WORDCHARS = "";
      };

      shellAliases = {
        vi = "nvim";
        vim = "nvim";
        v = "vim_opener";
        ls = "eza --icons --color=always";
        sl = "ls";
        grep = "grep --color=auto";
        back = "cd $OLDPWD";
        reload = "exec $SHELL -l";
        tkill = "tmux kill-server";

        git = "${pkgs.git}/bin/git";
        good = "${pkgs.git}/bin/git bisect good";
        bad = "${pkgs.git}/bin/git bisect bad";

        as = "agent-sandbox --follow-symlinks";

        ll = "eza --icons --color=always -lh --git";
        la = "eza --icons --color=always -lah --git";
        tree = "eza --icons --color=always --tree";
        python = "python3";
      };

      profileExtra = ''
        export GPG_TTY=$(tty)
        if ! pgrep -x "gpg-agent" > /dev/null; then
            ${pkgs.gnupg}/bin/gpgconf --launch gpg-agent
        fi

        export PATH=/run/current-system/sw/bin:$HOME/.nix-profile/bin:$PATH
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
            . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi

        [ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
        [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"

        FPATH=/opt/homebrew/share/zsh-completions:$FPATH

        # Display cached fortune instantly; regenerate in background for next session
        if [ $UID != '0' ] && [[ $- == *i* ]] && [ $TERM != 'dumb' ]; then
            FORTUNE_COW_CACHE="''${XDG_CACHE_HOME:-$HOME/.cache}/fortune-cow"
            [[ -f "$FORTUNE_COW_CACHE" ]] && cat "$FORTUNE_COW_CACHE"
            {
              ${pkgs.fortune}/bin/fortune -a fortunes wisdom | ${pkgs.cowsay}/bin/cowsay > "$FORTUNE_COW_CACHE.tmp" && \
              mv "$FORTUNE_COW_CACHE.tmp" "$FORTUNE_COW_CACHE"
            } &!
            unset FORTUNE_COW_CACHE
        fi
      '';

      initContent = lib.mkMerge [
        (lib.mkBefore ''
          # Enable Powerlevel10k instant prompt. Should stay close to the top of .zshrc.
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        '')
        ''
          autoload -Uz compinit
          if [[ -n $ZDOTDIR/.zcompdump(#qN.mh+24) ]]; then compinit; else compinit -C; fi

          bindkey -v
          bindkey '^f' autosuggest-accept
          bindkey '^p' history-search-backward
          bindkey '^n' history-search-forward
          bindkey '^[w' kill-region

          bindkey '^[[A' history-substring-search-up
          bindkey '^[[B' history-substring-search-down
          HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

          # zsh-vi-mode clobbers all bindings via deferred init.
          # Re-apply bindings after it initializes.
          function zvm_after_init() {
            bindkey '^f' autosuggest-accept
            bindkey '^p' history-search-backward
            bindkey '^n' history-search-forward
            bindkey '^[w' kill-region
            bindkey '^[[A' history-substring-search-up
            bindkey '^[[B' history-substring-search-down
          }

          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
          zstyle ':completion:*' menu no
          zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
          zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --icons --color=always $realpath'
          zstyle ':fzf-tab:complete:*:*' fzf-preview '${pkgs.bat}/bin/bat -n --color=always --line-range :500 $realpath 2>/dev/null || eza -1 --icons --color=always $realpath 2>/dev/null'
          zstyle ':completion:*:*:docker:*' option-stacking yes
          zstyle ':completion:*:*:docker-*:*' option-stacking yes

          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

          export HOMEBREW_PREFIX="/opt/homebrew"
          export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
          export HOMEBREW_REPOSITORY="/opt/homebrew"
          export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
          [ -z "''${MANPATH-}" ] || export MANPATH=":''${MANPATH#:}"
          export INFOPATH="/opt/homebrew/share/info:''${INFOPATH:-}"

          # Go up N directories
          up() { cd $(eval printf '../'%.0s {1..$1}) && pwd; }

          # um completions (cached at darwin-rebuild time)
          [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/um-completion.zsh" ]] && source "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/um-completion.zsh"
        ''
      ];

      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];

      antidote = {
        enable = true;
        plugins = [
          "getantidote/use-omz"

          "ohmyzsh/ohmyzsh path:plugins/1password"
          "ohmyzsh/ohmyzsh path:plugins/aws"
          "ohmyzsh/ohmyzsh path:plugins/brew"
          "ohmyzsh/ohmyzsh path:plugins/command-not-found"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/helm"
          "ohmyzsh/ohmyzsh path:plugins/kubectl"
          "ohmyzsh/ohmyzsh path:plugins/kubectx"
          "ohmyzsh/ohmyzsh path:plugins/podman"
          "ohmyzsh/ohmyzsh path:plugins/python"
          "ohmyzsh/ohmyzsh path:plugins/rust"
          "ohmyzsh/ohmyzsh path:plugins/safe-paste"
          "ohmyzsh/ohmyzsh path:plugins/sudo"
          "ohmyzsh/ohmyzsh path:plugins/tmux"
          "ohmyzsh/ohmyzsh path:plugins/virtualenv"

          "zsh-users/zsh-completions path:src kind:fpath"
          "zsh-users/zsh-history-substring-search"
          # "zdharma-continuum/fast-syntax-highlighting"
          "Aloxaf/fzf-tab"

          "romkatv/powerlevel10k"
        ];

      };
    };

  };

  targets.darwin = {
    defaults = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
    };
  };

  news.display = "silent";

}
