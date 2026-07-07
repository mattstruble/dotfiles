{ inputs, pkgs, lib, ... }:

# Extensions deliberately NOT included (redundant with AdNauseam + arkenfox + AdGuard Home):
# - ClearURLs (uBlock/AdNauseam handles URL parameter stripping)
# - Random User Agent (fingerprintingProtection already spoofs UA)
# - TrackMeNot (makes you more unique, not less)
# - Spoof Geolocation (geo.enabled = false covers this)
# - Skip Redirect (AdNauseam + ClearURLs built-in handles this)
# - Private Relay (Mozilla service, not relevant for Zen)

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # Zen/Firefox needs writable profiles.ini — HM symlinks to the read-only Nix store.
  # This activation script converts the symlink to a writable copy after each switch.
  home.activation.fixZenProfilesIni = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ZEN_DIR="$HOME/Library/Application Support/Zen"
    if [ -L "$ZEN_DIR/profiles.ini" ]; then
      cp -L "$ZEN_DIR/profiles.ini" "$ZEN_DIR/profiles.ini.tmp"
      rm "$ZEN_DIR/profiles.ini"
      mv "$ZEN_DIR/profiles.ini.tmp" "$ZEN_DIR/profiles.ini"
      chmod 644 "$ZEN_DIR/profiles.ini"
    fi
  '';

  # Bundle ID confirmed from /Applications/Zen.app/Contents/Info.plist
  targets.darwin.defaults."app.zen-browser.zen" = {
    EnterprisePoliciesEnabled = true;

    ExtensionSettings = {
      # AdNauseam — uBlock fork with ad-clicking for counter-surveillance.
      # Available on AMO (slug: adnauseam). adminSettings configured below via 3rdparty.Extensions.
      "adnauseam@rednoise.org" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/adnauseam/latest.xpi";
        installation_mode = "normal_installed";
      };

      # 1Password
      "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
        installation_mode = "normal_installed";
      };

      # SponsorBlock — skip YouTube sponsor segments
      "sponsorBlocker@ajay.app" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/sponsorblock/latest.xpi";
        installation_mode = "normal_installed";
      };

      # DeArrow — crowdsourced YouTube titles and thumbnails
      "deArrow@ajay.app" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/dearrow/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Facebook Container
      "@contain-facebook" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/facebook-container/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Vimium — keyboard-driven browsing
      "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/vimium-ff/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Karakeep — self-hosted bookmark manager (formerly Hoarder).
      # AMO slug: karakeep, guid: addon@karakeep.app.
      # Managed storage investigation: the extension uses the 'storage' permission but
      # ships no managed_storage schema in its manifest. Server URL must be configured
      # manually in the extension popup after install — no policy-based pre-configuration.
      "addon@karakeep.app" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/karakeep/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Auto Tab Discard — suspend inactive tabs to save memory
      "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/auto-tab-discard/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Enhancer for YouTube
      "enhancerforyoutube@maximerf.addons.mozilla.org" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/enhancer-for-youtube/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Disable Twitch Extensions
      "disable-twitch-extensions@rootonline.de" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/disable-twitch-extensions/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Old Reddit Redirect
      "{9063c2e9-e07c-4c2c-9646-cfe7ca8d0498}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/old-reddit-redirect/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Unpaywall — open access academic papers
      "{f209234a-76f0-4735-9920-eb62507a54cd}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/unpaywall/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Refined GitHub
      "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/refined-github-/latest.xpi";
        installation_mode = "normal_installed";
      };

      # arXiv Vanity — render arXiv papers as readable HTML
      "{e92bf629-488c-4d5f-8771-04812b17c143}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/arxiv-vanity/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Code Finder: CatalyzeX — find code for ML papers
      "{a3f8e50c-bc39-4e48-ae2f-2ed36fa6752b}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/code-finder-catalyzex/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Imagus — hover zoom for images
      "{00000f2a-7cde-4f20-83ed-434fcb420d71}" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/imagus/latest.xpi";
        installation_mode = "normal_installed";
      };

      # GNU Terry Pratchett — X-Clacks-Overhead header
      "jid1-HGPgB0x6133Hig@jetpack" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/gnu_terry_pratchett/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Dark Reader — dark mode for web content
      "addon@darkreader.org" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/darkreader/latest.xpi";
        installation_mode = "normal_installed";
      };
    };

    "3rdparty".Extensions = {
      # AdNauseam is a uBlock Origin fork — adminSettings format is identical.
      # Transcribed from programs/firefox.nix uBlock0@raymondhill.net config.
      "adnauseam@rednoise.org".adminSettings = {
        userSettings = rec {
          cloudStorageEnabled = false;
          importedLists = [
            "https://big.oisd.nl"
            "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
            # https://github.com/mchangrh/yt-neuter/blob/main/README.md
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/yt-neuter.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/sponsorblock.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noview.txt"
          ];
          externalLists = lib.concatStringsSep "\n" importedLists;
        };
        selectedFilterLists = [
          "adguard-annoyance"
          "adguard-cookies"
          "adguard-generic"
          "adguard-mobile"
          "adguard-mobile-app-banners"
          "adguard-other-annoyances"
          "adguard-popup-overlays"
          "adguard-social"
          "adguard-spyware"
          "adguard-spyware-url"
          "adguard-widgets"
          "block-lan"
          "curben-phishing"
          "dpollock-0"
          "easylist"
          "easyprivacy"
          "plowe-0"
          "ublock-abuse"
          "ublock-annoyances"
          "ublock-cookies-adguard"
          "ublock-badware"
          "ublock-filters"
          "ublock-privacy"
          "ublock-quick-fixes"
          "ublock-unbreak"
          "urlhaus-1"
          "https://big.oisd.nl"
          "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/yt-neuter.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/sponsorblock.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noview.txt"
        ];
        hiddenSettings = {
          # https://github.com/mchangrh/yt-neuter/blob/main/README.md#scriptlets
          userResourceLocation = "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/scriptlets.js";
        };
      };
    };
  };

  programs.zen-browser = {
    enable = true;

    # Homebrew cask provides the signed binary (required for 1Password integration).
    # ponytail: null package skips Nix-managed binary; Homebrew handles install.
    package = null;

    profiles.default = {
      # Mods: mechanism in place for future use.
      mods = [];

      settings = inputs.arkenfox-userjs.lib.userjs // {
        # --- Fingerprinting: granular protection, not the nuclear option ---
        # resistFingerprinting breaks many sites (letterboxing, canvas noise, etc.)
        # fingerprintingProtection is the modern per-API approach.
        "privacy.fingerprintingProtection" = true;
        "privacy.resistFingerprinting" = false;
        "privacy.resistFingerprinting.letterboxing" = false;
        # Keep all protections except timezone spoofing (timezone leaks real location
        # but spoofing breaks calendar apps and scheduling tools).
        "privacy.fingerprintingProtection.overrides" = "+AllProtections,-TimezoneOverride";
        # Full RFP in private windows only — maximum protection when needed
        "privacy.resistFingerprinting.pbmode" = true;

        # --- DNS: network-level AdGuard Home handles this; DoH is redundant ---
        "network.trr.mode" = 5; # 5 = disabled (off, use OS resolver)
        "doh-rollout.mode" = 0;
        "doh-rollout.self-enabled" = false;

        # --- WebRTC: disabled on personal machine; work host re-enables ---
        "media.peerconnection.enabled" = false;

        # --- 1Password handles credentials; disable built-in password/autofill ---
        "signon.rememberSignons" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        # --- Media ---
        "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = true;

        # --- SanitizeOnShutdown: clear ephemeral data, keep persistent state ---
        "privacy.sanitize.sanitizeOnShutdown" = true;
        "privacy.clearOnShutdown.cache" = true;
        "privacy.clearOnShutdown.downloads" = true;
        "privacy.clearOnShutdown.formdata" = true;
        "privacy.clearOnShutdown.offlineApps" = true;
        # Keep: browsing history, active sessions, cookies, site settings
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.sessions" = false;
        "privacy.clearOnShutdown.siteSettings" = false;
      };

      search = {
        force = true;
        default = "ddg";
        engines = {
          "google".metaData.hidden = true;
          "bing".metaData.hidden = true;
          "amazondotcom-us".metaData.hidden = true;
        };
      };

      liveFolders = {
        "Pull requests" = {
          id = "6007b674-05a3-4264-93ec-5d0d8572a14b";
          kind = "github:pull-requests";
          position = 400;
          github = {
            authorMe = true;
            assignedMe = true;
          };
        };
      };
    };
  };
}
