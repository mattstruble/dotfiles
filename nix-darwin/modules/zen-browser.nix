{
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # Zen/Firefox needs writable profiles.ini — HM symlinks to the read-only Nix store.
  # This activation script converts the symlink to a writable copy after each switch.
  home.activation.fixZenProfilesIni = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

      # Firefox Relay — generate email aliases to protect real address
      "private-relay@firefox.com" = {
        install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/private-relay/latest.xpi";
        installation_mode = "normal_installed";
      };
    };

    "3rdparty".Extensions = {
      # AdNauseam is a uBlock Origin fork — adminSettings format is identical.
      "adnauseam@rednoise.org".adminSettings = {
        userSettings = rec {
          cloudStorageEnabled = false;
          importedLists = [
            "https://big.oisd.nl"
            "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
            # https://github.com/mchangrh/yt-neuter
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/yt-neuter.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/sponsorblock.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noview.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noshorts.txt"
            "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/nolive.txt"
            # https://github.com/yokoffing/filterlists
            "https://raw.githubusercontent.com/yokoffing/filterlists/main/annoyance_list.txt"
            "https://raw.githubusercontent.com/yokoffing/filterlists/main/block_third_party_fonts.txt"
            # https://github.com/DandelionSprout/adfilt
            "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Dandelion%20Sprout's%20Anti-Malware%20List.txt"
          ];
          externalLists = lib.concatStringsSep "\n" importedLists;
        };
        selectedFilterLists = [
          # AdNauseam / uBlock built-in
          "user-filters"
          "adnauseam-filters"
          "ublock-filters"
          "ublock-badware"
          "ublock-privacy"
          "ublock-quick-fixes"
          "ublock-unbreak"
          "ublock-annoyances"
          "ublock-cookies-adguard"
          "ublock-cookies-easylist"
          # EasyList
          "easylist"
          "easyprivacy"
          "easylist-annoyances"
          "easylist-chat"
          "easylist-newsletters"
          "easylist-notifications"
          # AdGuard
          "adguard-generic"
          "adguard-mobile"
          "adguard-mobile-app-banners"
          "adguard-spyware-url"
          "adguard-cookies"
          "adguard-other-annoyances"
          "adguard-popup-overlays"
          "adguard-social"
          "adguard-widgets"
          # Fanboy
          "fanboy-cookiemonster"
          "fanboy-social"
          "fanboy-thirdparty_social"
          "fanboy-ai-suggestions"
          # Misc built-in
          "block-lan"
          "curben-phishing"
          "eff-dnt-whitelist"
          "plowe-0"
          "urlhaus-1"
          # External
          "https://big.oisd.nl"
          "https://github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/yt-neuter.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/sponsorblock.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noview.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/noshorts.txt"
          "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/filters/nolive.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/main/annoyance_list.txt"
          "https://raw.githubusercontent.com/yokoffing/filterlists/main/block_third_party_fonts.txt"
          "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Dandelion%20Sprout's%20Anti-Malware%20List.txt"
        ];
        userFilters = ''
          ! Re-enable save-to-playlist (blocked by yt-neuter)
          www.youtube.com#@#ytd-button-renderer:has(>yt-button-shape:has(> button:has-text(Save)):has(yt-icon))
          www.youtube.com#@#tp-yt-paper-item:has(yt-icon):has(yt-formatted-string:has-text(Save))
          www.youtube.com#@#yt-button-view-model:has(>button-view-model> button[aria-label="Save to playlist"])
        '';
        netWhitelist = ''
          chrome-extension-scheme
          moz-extension-scheme
        '';
        hiddenSettings = {
          # https://github.com/mchangrh/yt-neuter#scriptlets
          userResourcesLocation = "https://raw.githubusercontent.com/mchangrh/yt-neuter/main/scriptlets.js";
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
      mods = [
        "d8b79d4a-6cba-4495-9ff6-d6d30b0e94fe" # Better Active Tab
        "272850c0-36b4-4867-be8f-7c4b5942069f" # DoubleClickless
        "4ab93b88-151c-451b-a1b7-a1e0e28fa7f8" # No Sidebar Scrollbar
      ];

      presets.betterfox.enable = true;

      settings = {
        # --- Fingerprinting: modern per-API protection ---
        "privacy.fingerprintingProtection" = true;
        "privacy.fingerprintingProtection.overrides" = "+AllProtections,-TimezoneOverride";
        "privacy.resistFingerprinting.pbmode" = true;

        # --- Bounce tracking: purge cookies from redirect trackers ---
        "privacy.bounceTrackingProtection.mode" = 1;

        # --- TLS: reject servers without safe renegotiation ---
        "security.ssl.require_safe_negotiation" = true;

        # --- DNS: network-level AdGuard Home handles this ---
        "network.trr.mode" = 5;
        "doh-rollout.mode" = 0;
        "doh-rollout.self-enabled" = false;

        # --- WebRTC: disabled on personal machine ---
        "media.peerconnection.enabled" = false;

        # --- 1Password handles credentials ---
        "signon.rememberSignons" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;

        # --- Media ---
        "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = true;

        # --- SanitizeOnShutdown: clear ephemeral, keep persistent ---
        "privacy.sanitize.sanitizeOnShutdown" = true;
        "privacy.clearOnShutdown.cache" = true;
        "privacy.clearOnShutdown.downloads" = true;
        "privacy.clearOnShutdown.formdata" = true;
        "privacy.clearOnShutdown.offlineApps" = true;
        "privacy.clearOnShutdown.cookies" = false;
        "privacy.clearOnShutdown.history" = false;
        "privacy.clearOnShutdown.sessions" = false;
        "privacy.clearOnShutdown.siteSettings" = false;
        "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
        "privacy.clearOnShutdown_v2.cache" = true;
        "privacy.clearOnShutdown_v2.siteSettings" = false;
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

    };
  };
}
