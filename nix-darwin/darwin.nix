{ pkgs
, lib
, config
, hostname
, inputs
, ...
}:

let
  home = builtins.getEnv "HOME";
  userName = builtins.getEnv "USER";
  tmpdir = "/tmp";
  xdg_configHome = "${home}/.config";
  xdg_dataHome = "${home}/local/share";
  xdg_cacheHome = "${home}/.cache";

in
{
  security.pam.enableSudoTouchIdAuth = true;

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

  nix = {
    package = pkgs.nix;
    useDaemon = true;
    gc.automatic = true;
    optimise.automatic = true;

    settings = {
      trusted-users = [
        "${userName}"
        "@admin"
      ];

      max-jobs = 8;
      cores = 2;

      substituters = [
        "https://cache.nixos.org/"
      ];

      trusted-substituters = [ ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];

      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    # This entry lets us to define a system registry entry so that
    # `nixpkgs#foo` will use the nixpkgs that nix-darwin was last built with,
    # rather than whatever is the current unstable version.
    #
    # See https://yusef.napora.org/blog/pinning-nixpkgs-flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    nixPath = lib.mkForce (
      lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry
      ++ [
        {
          ssh-config-file = "${home}/.ssh/config";
          ssh-auth-sock = "${xdg_configHome}/gnupg/S.gpg-agent.ssh";
          darwin-config = "${home}/src/nix/darwin.nix";
          hm-config = "${home}/src/nix/home.nix";
        }
      ]
    );

    distributedBuilds = false;

    extraOptions = ''
      gc-keep-derivations = true
      gc-keep-outputs = true
      # secret-key-files = ${xdg_configHome}/gnupg/nix-signing-key.sec
    '';
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

    taps = [
      "1password/tap"
      "felixkratz/formulae"
      "koekeishiya/formulae"
    ];

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
      # "python-toml"
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
      "wezterm"
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

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = false;
      allowInsecure = false;
      allowUnsupportedSystem = false;
    };
  };

  system = {
    stateVersion = 4;

    # activationScripts are executed every time you boot the system or run
    # `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and
      # apply them to the current session, so we do not need to logout and
      # login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      ".GlobalPreferences" = {
        "com.apple.mouse.scaling" = 0.8;
      };

      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        AppleKeyboardUIMode = 3;
        AppleMeasurementUnits = "Inches";
        AppleMetricUnits = 0;
        ApplePressAndHoldEnabled = false;
        AppleShowAllExtensions = true;
        AppleTemperatureUnit = "Fahrenheit";
        NSAutomaticWindowAnimationsEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        "com.apple.keyboard.fnState" = true;
        _HIHideMenuBar = true;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };
      CustomUserPreferences = {
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
          _FXSortFoldersFirst = true;
          # When performing a search, search the current folder by default
          FXDefaultSearchScope = "SCcf";
        };

        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        "com.apple.spaces" = {
          "spans-displays" = 0; # Display have seperate spaces
        };

        "com.apple.WindowManager" = {
          EnableStandardClickToShowDesktop = 0; # Click wallpaper to reveal desktop
          StandardHideDesktopIcons = 0; # Show items on desktop
          HideDesktop = 0; # Do not hide items on desktop & stage manager
          StageManagerHideWidgets = 0;
          StandardHideWidgets = 0;
        };

        "com.apple.screencapture" = {
          location = "~/Pictures/screenshots";
          type = "png";
        };

        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };

        # Prevent Photos from opening automatically when devices are plugged in
        "com.apple.ImageCapture".disableHotPlug = true;

        "com.apple.print.PrintingPrefs" = {
          # Automatically quit printer app once the print jobs complete
          "Quit When Finished" = true;
        };

        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          # Check for software updates daily, not just once per week
          ScheduleFrequency = 1;
          # Download newly available updates in background
          AutomaticDownload = 1;
          # Install System data files & security updates
          CriticalUpdateInstall = 1;
        };
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;

        # Turn on app auto-update
        "com.apple.commerce".AutoUpdate = true;

        dock = {
          autohide = true;
          expose-group-by-app = false;
          largesize = 64;
          launchanim = false;
          magnification = true;
          mineffect = "genie";
          mru-spaces = false;
          orientation = "bottom";
          show-process-indicators = true;
          show-recents = false;
          static-only = true;
          tilesize = 32;
          wvous-bl-corner = "Disabled";
          wvous-br-corner = "Disabled";
          wvous-tr-corner = "Disabled";
          wvous-tl-corner = "Disabled";
        };

        finder = {
          AppleShowAllExtensions = true;
          CreateDesktop = false;
          FXEnableExtensionChangeWarning = false;
          ShowPathbar = true;
        };

        trackpad = {
          Clicking = false;
          TrackpadThreeFingerDrag = true;
        };
      };

    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  # };

}
