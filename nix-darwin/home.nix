{ pkgs
, lib
, config
, hostname
, inputs
, ca-bundle_path ? "${pkgs.cacert}/etc/ssl/certs"
, ca-bundle_crt ? "${ca-bundle_path}/ca-bundle.crt"
, ...
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
        ".vimrc".source = mkLink "${path}/vim/.vimrc";

        ".zshrc".source = mkLink "${path}/zsh/.zshrc";
        ".zprofile".source = mkLink "${path}/zsh/.zprofile";
        ".subzsh".source = mkLink "${path}/zsh/subzsh";

        ".local/bin/vim_opener".source = mkLink "${path}/commands/.local/bin/vim_opener";
      };
  };

  xdg.configFile =
    let
      mkLink = config.lib.file.mkOutOfStoreSymlink;
    in
    {
      "aerospace".source = mkLink "${path}/aerospace/.config/aerospace";
      "nvim".source = mkLink "${path}/nvim/.config/nvim";
      "tmux".source = mkLink "${path}/tmux/.config/tmux";
      "wezterm".source = mkLink "${path}/wezterm/.config/wezterm";
      "ghostty".source = mkLink "${path}/ghostty/.config/ghostty";
      "harper-ls".source = mkLink "${path}/harper-ls/.config/harper-ls";
      "lazygit".source = mkLink "${path}/lazygit/.config/lazygit";
      "sketchybar".source = mkLink "${path}/sketchybar/.config/sketchybar";
      "yamlfmt".source = mkLink "${path}/yamlfmt/.config/yamlfmt";

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

  programs = {
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
        "*.null-ls*"
        ".direnv"
        ".envrc"
        "Thumbs.db"
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
          default = "tracking";
          autoSetupRemote = true;
          # recurseSubmodules = "check";
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
          controlPersist = "1800";

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
        ALTERNATE_EDITOR = "${pkgs.vim}/vin/vi";
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
      '';

      initContent = ''
        autoload -Uz compinit && compinit

        source .profile

        bindkey -v
        bindkey '^f' autosuggest-accept
        bindkey '^p' history-search-backward
        bindkey '^n' history-search-forward
        bindkey '^[w' kill-region

        bindkey '^[[A' history-substring-search-up # or '\eOA'
        bindkey '^[[B' history-substring-search-down # or '\eOB'
        HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
        zstyle ':completion:*:*:docker:*' option-stacking yes
        zstyle ':completion:*:*:docker-*:*' option-stacking yes

        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        [[ ! -f ~/.profile ]] || source ~/.profile

        if [ $(command -v fortune) ] && [ $UID != '0' ] && [[ $- == *i* ]] && [ $TERM != 'dumb' ]; then
            ### Cowsay At Login ###
            if [ $(command -v cowsay) ]; then
                fortune -a fortunes wisdom | cowsay
            else
                fortune -a fortunes wisdom
            fi
        fi

        export PATH="$HOME/.pyenv:$PATH"
        export PYENV_VIRTUALENV_DISABLE_PROMPT=1

        eval "$(pyenv init --path)"
        eval "$(pyenv init -)"
        eval "$(pyenv virtualenv-init -)"
        eval "$(${brew_path}/brew shellenv)"
      '';

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
          "ohmyzsh/ohmyzsh path:plugins/ansible"
          "ohmyzsh/ohmyzsh path:plugins/aws"
          "ohmyzsh/ohmyzsh path:plugins/bazel"
          "ohmyzsh/ohmyzsh path:plugins/brew"
          "ohmyzsh/ohmyzsh path:plugins/command-not-found"
          "ohmyzsh/ohmyzsh path:plugins/direnv"
          # "ohmyzsh/ohmyzsh path:plugins/docker"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/fzf"
          "ohmyzsh/ohmyzsh path:plugins/helm"
          "ohmyzsh/ohmyzsh path:plugins/kubectl"
          "ohmyzsh/ohmyzsh path:plugins/podman"
          "ohmyzsh/ohmyzsh path:plugins/poetry"
          "ohmyzsh/ohmyzsh path:plugins/pyenv"
          "ohmyzsh/ohmyzsh path:plugins/python"
          "ohmyzsh/ohmyzsh path:plugins/rust"
          "ohmyzsh/ohmyzsh path:plugins/safe-paste"
          "ohmyzsh/ohmyzsh path:plugins/tmux"
          "ohmyzsh/ohmyzsh path:plugins/vagrant"
          "ohmyzsh/ohmyzsh path:plugins/vi-mode"
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
