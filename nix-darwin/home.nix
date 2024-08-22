{ pkgs
, lib
, config
, hostname
, inputs
, ...
}:

let
  home = builtins.getEnv "HOME";
  tmpdir = "/tmp";
  userName = builtins.getEnv "USER";
  onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  # onePassPath = "~/.1password/agent.sock";

  ca-bundle_path = "${pkgs.cacert}/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-bundle.crt";
  brew_path =
    if pkgs.stdenv.targetPlatform.isx86_64 then "/usr/local/Homebrew/bin" else "/opt/homebrew/bin";
in
{
  imports = [ ./hosts/${hostname}/home.nix ];

  home = {
    stateVersion = "23.11";
    enableNixpkgsReleaseCheck = false;

    packages = import ./packages.nix pkgs;

    sessionVariables = {
      FONTCONFIG_FILE = "${config.xdg.configHome}/fontconfig/fonts.conf";
      FONTCONFIG_PATH = "${config.xdg.configHome}/fontconfig";
      GNUPGHOME = "${config.xdg.configHome}/gnupg";
      JAVA_OPTS = "-Xverify:none";
      LESSHISTFILE = "${config.xdg.cacheHome}/less/history";
      NIX_CONF_DIR = "${config.xdg.configHome}/nix";
      VAGRANT_HOME = "${config.xdg.dataHome}/vagrant";
      TZ = "America/New_York";

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

    file = let mkLink = config.lib.file.mkOutOfStoreSymlink; in {
        ".curlrc".text = ''
            capath=${ca-bundle_path}
            cacert=${ca-bundle_crt}
        '';

        ".wgetrc".text = ''
            ca_directory = ${ca-bundle_path}
            ca_certificate = ${ca-bundle_crt}
        '';

        "${config.xdg.configHome}/aerospace".source = mkLink "../aerospace/.config/aerospace";
        "${config.xdg.configHome}/nvim".source = mkLink "../nvim/.config/nvim";
        ".p10k.zsh".source = mkLink "../p10k/.p10k.zsh";
        "${config.xdg.configHome}/skhd".source = mkLink "../skhd/.config/skhd";
        "${config.xdg.configHome}/tmux".source = mkLink "../tmux/.config/tmux";
        ".vimrc".source = mkLink "../vim/.vimrc";
        "${config.xdg.configHome}/wezterm".source = mkLink "../wezterm/.config/wezterm";
        "${config.xdg.configHome}/yabai".source = mkLink "../yabai/.config/yabai";

        ".zshrc".source = mkLink "../zsh/.zshrc";
        ".zprofile".source = mkLink "../zsh/.zprofile";
        ".subzsh".source = mkLink "../zsh/subzsh";
    };
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
    neovim.enable = true;

    home-manager = {
      enable = true;
      path = "${config.xdg.configHome}/nix/home-manager";
    };

    texlive = {
      enable = true;
      extraPackages = tpkgs: {
        inherit (tpkgs) scheme-full texdoc latex2e-help-texinfo;
        pkgFilter = pkg: pkg.tlType == "run" || pkg.tlType == "bin" || pkg.pname == "latex2e-help-texinfo";
      };
    };

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
      package = pkgs.gitFull;

      signing = {
                key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEM+saqSDNRJt5qpi6lltteSsdY7wNVz5Is2ywVFcyzv";
                signByDefault = true;
            };

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
      };

      extraConfig = {
        core = {
          editor = "neovim";
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

        credential.helper = "${pkgs.pass-git-helper}/bin/pass-git-helper";
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

      controlMaster = "auto";
      controlPath = "${tmpdir}/ssh-%u-%r@%h:%p";
      controlPersist = "1800";

      forwardAgent = true;
      serverAliveInterval = 60;

      hashKnownHosts = true;
      userKnownHostsFile = "${config.xdg.configHome}/ssh/known_hosts";

      extraConfig = ''
        Host *
            IdentityAgent ${onePassPath}
      '';

    };

  };

}
