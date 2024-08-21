{ pkgs, lib, config, hostname, inputs, ... }:

let
  home = builtins.getEnv "HOME";
  tmpdir = "/tmp";
  userName = builtins.getEnv "USER";

  ca-bundle_path = "${pkgs.cacert}/etc/ssl/certs";
  ca-bundle_crt = "${ca-bundle_path}/ca-bundle.crt";
  brew_path = if pkgs.stdenv.targetPlatform.isx86_64
              then "/usr/local/Homebrew/bin"
              else "/opt/homebrew/bin";
in
{
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
                pkgFilter = pkg:
                    pkg.tlType == "run"
                    || pkg.tlType == "bin"
                    || pkg.pname == "latex2e-help-texinfo";
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


    };

  }
