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
  # onePassPath = "~/.1password/agent.sock";

  # ca-bundle_path = "${pkgs.cacert}/etc/ssl/certs";
  # ca-bundle_crt = "${ca-bundle_path}/ca-bundle.crt";
  brew_path = "/opt/homebrew/bin";
  # if pkgs.stdenv.targetPlatform.isx86_64 then "/usr/local/Homebrew/bin" else "/opt/homebrew/bin";
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
      #NIX_CONF_DIR = "${config.xdg.configHome}/nix";
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

      PYENV_ROOT = "${home}/.pyenv";
      PYENV_VIRTUALENV_DISABLE_PROMPT = "1";

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
      "wezterm".source = mkLink "${path}/wezterm/.config/wezterm";
      "yamlfmt".source = mkLink "${path}/yamlfmt/.config/yamlfmt";

      "opencode/tui.json".source = mkLink "${path}/opencode/.config/opencode/tui.json";
      "opencode/themes".source = mkLink "${path}/opencode/.config/opencode/themes";

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
      skills = [

        {
          source = inputs.skills-superpowers;
          exclude = [
            "brainstorming"
            "requesting-code-review"
            "test-driven-development"
            "using-superpowers"
            "writing-skills"
          ];
        }

        inputs.skills-mattstruble
      ];

      mcpServers = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
      };

      opencode = {
        agentsFile = config.lib.file.mkOutOfStoreSymlink "${path}/opencode/.config/opencode/AGENTS.md";
        config = {
          "$schema" = "https://opencode.ai/config.json";
          agent = {
            orchestrator = {
              tools = {
                "github*" = true;
              };
            };
            fetcher = {
              tools = {
                "context7*" = false;
              };
            };
          };
          permission = {
            external_directory = {
              "/tmp/opencode-wt/**" = "allow";
              "/private/tmp/opencode-wt/**" = "allow";
              "~/.opencode/**" = "allow";
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

    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };

    home-manager = {
      enable = true;
      # path = "${config.xdg.configHome}/nix/home-manager";
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
    };

    bash = {
      enable = true;
      bashrcExtra = lib.mkBefore ''
        source /etc/bashrc

        export PATH="$HOME/.pyenv:$PATH"
        export PYENV_VIRTUALENV_DISABLE_PROMPT=1

        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
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
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEM+saqSDNRJt5qpi6lltteSsdY7wNVz5Is2ywVFcyzv";
        signByDefault = true;
      };

      settings = {

        aliases = {
          amend = "commit --amend -C HEAD";
          authors =
            "!\"${pkgs.git}/bin/git log --pretty=format:%aN"
            + " | ${pkgs.coreutils}/bin/sort"
            + " | ${pkgs.coreutils}/bin/uniq -c"
            + " | ${pkgs.coreutils}/bin/sort -rn\"";
          b = "branch --color -v";
          ca = "commit --amend";
          changes = "diff --name-status -r";
          clone = "clone --bare --recursive";
          co = "checkout";
          cp = "cherry-pick";
          dc = "diff --cached";
          dh = "diff HEAD";
          ds = "diff --staged";
          from = "!${pkgs.git}/bin/git bisect start && ${pkgs.git}/bin/git bisect bad HEAD && ${pkgs.git}/bin/git bisect good";
          ls-ignored = "ls-files --exclude-standard --ignored --others";
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
          untracked = "git fetch --prune && git branch -r | awk '{print \$1}' | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk '{print \$1}'";
          remove-untracked = "git fetch --prune && git branch -r | awk '{print \$1}' | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk '{print \$1}' | xargs git branch -d";
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
        commit = {
          gpgsign = true;
          status = false;
        };
        gpg.format = "ssh";
        # "gpg \"ssh\"".program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
        "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

        credential.helper = "store";
        ghi.token = "!${pkgs.pass}/bin/pass show api.github.com | head -1";
        hub.protocol = "${pkgs.openssh}/bin/ssh";
        mergetool.keepBackup = true;
        pull.rebase = true;
        rebase.autosquash = true;
        rerere.enabled = true;
        init.defaultBranch = "main";
        tag.gpgsign = true;
        lfs.enable = true;

        "merge \"ours\"".driver = true;
        "magithub \"ci\"".enabled = false;

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

        # "merge \"merge-changelog\"" = {
        #   name = "GNU-style ChangeLog merge driver";
        #   driver = "${pkgs.git-scripts}/bin/git-merge-changelog %O %A %B";
        # };

        merge = {
          conflictstyle = "diff3";
          stat = true;
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

        "filter \"media\"" = {
          required = true;
          clean = "${pkgs.git}/bin/git media clean %f";
          smudge = "${pkgs.git}/bin/git media smudge %f";
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

        advice = {
          statusHints = false;
          pushNonFastForward = false;
          objectNameWarning = "false";
        };

        "filter \"lfs\"" = {
          clean = "${pkgs.git-lfs}/bin/git-lfs clean -- %f";
          smudge = "${pkgs.git-lfs}/bin/git-lfs smudge --skip -- %f";
          required = true;
        };
      };

    };

    ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks = {
        "*" = {
          compression = true;
          addKeysToAgent = "yes";
          controlMaster = "auto";
          controlPath = "${tmpdir}/ssh-%u-%r@%h:%p";
          controlPersist = "no";

          forwardAgent = true;
          serverAliveInterval = 60;

          hashKnownHosts = true;
          userKnownHostsFile = "${home}/.ssh/known_hosts";
          identityAgent = "${onePassPath}";
        };
      };
    };

    zsh = {
      dotDir = "${config.xdg.configHome}/zsh";

      enable = true;
      enableCompletion = false;

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
        SSH_AUTH_SOCK = "${onePassPath}";
        TINC_USE_NIX = "yes";
        WORDCHARS = "";
      };

      shellAliases = {
        vi = "nvim";
        vim = "nvim";
        v = "vim_opener";
        ls = "${pkgs.coreutils}/bin/ls -h --color=auto";
        sl = "ls";
        grep = "grep --color=auto";
        back = "cd $OLDPWD";
        reload = "exec $SHELL -l";
        tkill = "tmux kill-server";

        git = "${pkgs.git}/bin/git";
        good = "${pkgs.git}/bin/git bisect good";
        bad = "${pkgs.git}/bin/git bisect bad";

        as = "agent-sandbox --follow-symlinks";

        ll = "ls -lha";
        la = "ls -A";
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

        if type brew &>/dev/null; then
          FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
        fi

        # pyenv (must run before .zshrc so OMZ pyenv plugin finds shims in PATH)
        if [ -d "$PYENV_ROOT/bin" ]; then
          export PATH="$PYENV_ROOT/bin:$PATH"
        fi
        if command -v pyenv >/dev/null 2>&1; then
          eval "$(pyenv init --path)"
        fi

        if [ $(command -v fortune) ] && [ $UID != '0' ] && [[ $- == *i* ]] && [ $TERM != 'dumb' ]; then
            ### Cowsay At Login ###
            if [ $(command -v cowsay) ]; then
                fortune -a fortunes wisdom | cowsay
            else
                fortune -a fortunes wisdom
            fi
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
          autoload -Uz compinit && compinit

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
          zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
          zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
          zstyle ':completion:*:*:docker:*' option-stacking yes
          zstyle ':completion:*:*:docker-*:*' option-stacking yes

          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

          eval "$(${brew_path}/brew shellenv)"

          # Extract from most archive types
          function extract {
            echo Extracting $1 ...
            if [ -f $1 ] ; then
              case $1 in
                *.tar.bz2)  tar xjf $1      ;;
                *.tar.gz)   tar xzf $1      ;;
                *.bz2)      bunzip2 $1      ;;
                *.rar)      rar x $1        ;;
                *.gz)       gunzip $1       ;;
                *.tar)      tar xf $1       ;;
                *.tbz2)     tar xjf $1      ;;
                *.tgz)      tar xzf $1      ;;
                *.zip)      unzip $1        ;;
                *.Z)        uncompress $1   ;;
                *.7z)       7z x $1         ;;
                *)          echo "'$1' cannot be extracted via extract()" ;;
              esac
            else
              echo "'$1' is not a valid file"
            fi
          }

          # Go up N directories
          up() { cd $(eval printf '../'%.0s {1..$1}) && pwd; }

          # um completions
          eval "$(um --completion)"

          # npm global bin
          export PATH="$PATH:$(npm config get prefix)/bin"
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
          "ohmyzsh/ohmyzsh path:plugins/direnv"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/fzf"
          "ohmyzsh/ohmyzsh path:plugins/helm"
          "ohmyzsh/ohmyzsh path:plugins/kubectl"
          "ohmyzsh/ohmyzsh path:plugins/kubectx"
          "ohmyzsh/ohmyzsh path:plugins/podman"
          "ohmyzsh/ohmyzsh path:plugins/pyenv"
          "ohmyzsh/ohmyzsh path:plugins/python"
          "ohmyzsh/ohmyzsh path:plugins/rust"
          "ohmyzsh/ohmyzsh path:plugins/safe-paste"
          "ohmyzsh/ohmyzsh path:plugins/sudo"
          "ohmyzsh/ohmyzsh path:plugins/tmux"
          "ohmyzsh/ohmyzsh path:plugins/virtualenv"
          "ohmyzsh/ohmyzsh path:plugins/z"
          "ohmyzsh/ohmyzsh path:plugins/zoxide"

          "zsh-users/zsh-completions path:src kind:fpath"
          "zsh-users/zsh-autosuggestions"
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
