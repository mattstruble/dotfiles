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
  path = builtins.getEnv "DOTFILES_PATH";

in
{
  # security.pam.enableSudoTouchIdAuth = true;
  security.pam.services.sudo_local.touchIdAuth = true;
  environment = {
    darwinConfig = "${path}/nix-darwin";
  };

  # services = {
  #   nix-daemon.enable = true;
  # };

  users = {
    users."${userName}" = {
      name = "${userName}";
      home = "${home}";
      shell = pkgs.zsh;
    };
  };

  nix = {
    enable = false;
    package = pkgs.nix;
    # useDaemon = true;

    gc = {
      #automatic = true;
      #options = "--delete-older-than 30d";
    };

    optimise = {
      #user = "${userName}";
      #automatic = true;
    };

    settings = {
      allow-dirty = true;

      allowed-users = [ "*" ];

      build-users-group = "nixbld";
      builders-use-substitutes = true;

      eval-cache = true;

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      extra-nix-path = "nixpkgs=flake:nixpkgs";

      # filter-syscalls = true;
      flake-registry = "https://github.com/NixOS/flake-registry/raw/master/flake-registry.json";
      http-connections = 25;
      http2 = true;
      impersonate-linux-26 = false;

      keep-going = true;

      max-jobs = "auto";

      substitute = true;
      substituters = [
        "https://cache.nixos.org/"
      ];

      trusted-substituters = [
        "https://cache.flakehub.com"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM= cache.flakehub.com-4:Asi8qIv291s0aYLyH6IOnr5Kf6+OF14WVjkE6t3xMio= cache.flakehub.com-5:zB96CRlL7tiPtzA9/WKyPkp3A2vqxqgdgyTVNGShPDU= cache.flakehub.com-6:W4EGFwAGgBj3he7c5fNh9NkOXw0PUVaxygCVKeuvaqU= cache.flakehub.com-7:mvxJ2DZVHn/kRxlIaxYNMuDG1OvMckZu32um1TadOR8= cache.flakehub.com-8:moO+OVS0mnTjBTcOUh2kYLQEd59ExzyoW1QgQ8XAARQ= cache.flakehub.com-9:wChaSeTI6TeCuV/Sg2513ZIM9i0qJaYsF+lZCXg0J6o= cache.flakehub.com-10:2GqeNlIp6AKp4EF2MVbE1kBOp9iBSyo0UPR9KoR0o1Y="
      ];

      trusted-users = [
        "${userName}"
        "@admin"
        "@wheel"
      ];

      # upgrade-nix-store-path-url = "https://install.determinate.systems/nix-upgrade/stable/universal";
      use-case-hack = false;
      use-registries = true;
      use-sqlite-wal = true;

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

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
      extraFlags = [
        "--force"
      ];
    };

    taps = [
      "1password/tap"
      "FelixKratz/formulae"
      "nikitabobko/tap"
    ];

    brews = [
      "bibtexconv"
      "borders"
      "ical-buddy"
      "markdown-toc"
      "pyenv-virtualenv"
    ];

    casks = [
      "1password"
      "aerospace"
      "alfred"
      "flux"
      "font-iosevka-nerd-font"
      "ghostty"
      "menuwhere"
      "monitorcontrol"
      "obsidian"
      "only-switch"
      "scroll-reverser"
      "wacom-tablet"
      "zen-browser"
    ];

    masApps = {
      "CopyClip" = 595191960;
      "Dropover" = 1355679052;
      "Endel" = 1346247457;
      "Hidden Bar" = 1452453066;
      "Hyperduck" = 6444667067;
      "Grab2Text" = 6475956137;
      "Pure Paste" = 1611378436;
      "Slack" = 803453959;
      "TickTick" = 966085870;
      "Velja" = 1607635845;
      "Unsplash Wallpapers" = 1284863847;
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
        "com.apple.mouse.scaling" = 1.0;
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
          location = "~/Downloads";
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

}
