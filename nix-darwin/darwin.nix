{ pkgs, lib, config, hostname, inputs, ... }:

let
  home = builtins.getEnv "HOME";
  userName = builtins.getEnv "USER";
  tmpdir = "/tmp";
  xdg_configHome = "${home}/.config";
  xdg_dataHome = "${home}/local/share";
  xdg_cacheHome = "${home}/.cache";

in
{
  services = {
    nix-daemon.enable = true;
    activate-system.enable = true;
  };

  users = {
    users."${userName}" = {
      name = "${userName}";
      home = "${home}";
      shell = pkgs.zsh;
    };
  };

  fonts.packages = with pkgs; [ iosevka ];

  # progams = {
  #     zsh = {
  #         enable = true;
  #         enableCompletion = false;
  #     }
  # };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [ "1password/tap" "felixkratz/formulae" "koekeishiya/formulae" ];

    brews = [
      "aws-shell"
      "bibtex2html"
      "bibtexconv"
      "borders"
      "docker-completion"
      "ical-buddy"
      "markdown-toc"
      "mas"
      "pyenv-virtualenv"
      "python-toml"
      "pyyaml"
    ];

    casks = [
      "1password"
      "1password-cli"
      "flux"
      "floorp"
      "font-iosevka-nerd-font"
      "godot"
      "iterm2"
      "mactex"
      "menuwhere"
      "monitorcontrol"
      "standard-notes"
      # "vagrant"
      # "virtualbox"
      "wacom-tablet"
      "yubico-yubikey-manager"
    ];

    masApps = {
      "CopyClip" = 595191960;
      "Dropover" = 1355679052;
      "Endel" = 1346247457;
      "Hidden Bar" = 1452453066;
      "Pure Paste" = 1611378436;
      "Slack" = 803453959;
      "Velja" = 1607635845;

    };
  };

}
