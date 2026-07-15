{
  pkgs,
  lib,
  config,
  hostname,
  inputs,
  ...
}:

let
  userName = import ./hosts/${hostname}/username.nix;
  home = "/Users/${userName}";
  path = "${home}/dotfiles";

in
{
  imports =
    [ ]
    ++ lib.optional (builtins.pathExists ./hosts/${hostname}/darwin.nix) ./hosts/${hostname}/darwin.nix;
  # security.pam.enableSudoTouchIdAuth = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  environment = {
    darwinConfig = "${path}/nix-darwin";
    variables.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
  };

  programs.zsh = {
    enableGlobalCompInit = false;
    enableBashCompletion = false;
  };

  determinateNix = {
    enable = true;
    nixosVmBasedLinuxBuilder.enable = false;

    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    determinateNixd = {
      garbageCollector.strategy = "automatic";
    };

    customSettings = {
      trusted-users = [
        userName
        "@admin"
        "@wheel"
      ];
    };
  };

  users = {
    users."${userName}" = {
      name = "${userName}";
      home = "${home}";
      shell = pkgs.zsh;
    };
  };

  fonts.packages = with pkgs; [ nerd-fonts.iosevka ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      extraEnv.HOMEBREW_NO_REQUIRE_TAP_TRUST = "1";
    };

    taps = [
      "1password/tap"
      "FelixKratz/formulae"
      "nikitabobko/tap"
    ];

    brews = [
      "bibtexconv"
      {
        name = "borders";
        start_service = true;
        restart_service = "changed";
      }
      {
        name = "colima";
        # start_service = true;
        # restart_service = "changed";
      }
      "docker"
      "docker-compose"
      "docker-buildx"
      "ical-buddy"
      "markdown-toc"
      "mas"
      {
        name = "sketchybar";
        start_service = true;
        restart_service = "changed";
      }
      "rtk"
      "uv"
      "zsh-completions"
    ];

    casks = [
      "1password"
      "aerospace"
      "alfred"
      "flux-app"
      "font-iosevka-nerd-font"
      "kitty"
      "menuwhere"
      "monitorcontrol"
      "navigator"
      "only-switch"
      "scroll-reverser"
      #"wacom-tablet"
      "zen"
    ];

    masApps = {
      #"CopyClip" = 595191960;
      #"Dropover" = 1355679052;
      #"Endel" = 1346247457;
      #"Hidden Bar" = 1452453066;
      #"Hyperduck" = 6444667067;
      #"Grab2Text" = 6475956137;
      #"Pure Paste" = 1611378436;
      #"Slack" = 803453959;
      #"TickTick" = 966085870;
      #"Velja" = 1607635845;
      #"Unsplash Wallpapers" = 1284863847;
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

    primaryUser = "${userName}";
    stateVersion = 4;

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

  system.activationScripts.postActivation.text = ''
    echo "pruning nix generations older than 14d..." >&2
    ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 14d > /dev/null
  '';

  documentation.enable = false;
  documentation.man.enable = true;

  system.tools.darwin-uninstaller.enable = false;

}
