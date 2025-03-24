# Configure firefox addons and settings
# https://discourse.nixos.org/t/declare-firefox-extensions-and-settings/36265
# https://github.com/Kreyren/nixos-config/blob/bd4765eb802a0371de7291980ce999ccff59d619/nixos/users/kreyren/home/modules/web-browsers/firefox/firefox.nix#L116-L148
{ config, pkgs, ... }:

let
  lock-false = {
    Value = false;
    status = "locked";
  };
  lock-true = {
    Value = true;
    Status = "locked";
  };
in
{
  programs = {
    firefox = {
      enable = true;
      package = pkgs.wrapFirefox pkgs.firefox-unwrapped {

        # ---- POLICIES ----
        # Check about:policies#documentation for options.
        extraPolicies = {
          AppAutoUpdate = false;
          AutofillCreditCardEnabled = false;
          BackgroundAppUpdate = false;
          DefaultDownloadDirectory = "~/Downloads/";
          DisableAccounts = true;
          DisableDesktopBackground = true;
          DisableFirefoxScreenshots = true;
          DisableFirefoxStudies = true;
          DisableForgetButton = true;
          DisableFormHistory = true;
          DisableMasterPasswordCreation = true;
          DisablePasswordReveal = true;
          DisableProfileImport = true;
          DisableProfileRefresh = true;
          DisablePocket = true;
          DisableTelemetry = true;
          DisplayBookmarksToolbar = "never";
          DisplayMenuBar = "default-off";
          EnableTrackingProtection = {
            Value = true;
            Locked = true;
            Cryptomining = true;
            Fingerprinting = true;
            EmailTracking = true;
          };
          EncryptedMediaExtensions = {
            Enabled = true;
            Locked = true;
          };
          FirefoxHome = {
            Search = true;
            TopSites = true;
            SponsoredTopSites = false;
            Highlights = true;
            Pocket = false;
            SponsoredPocket = false;
            Snippets = false;
            Locked = true;
          };
          FirefoxSuggest = {
            WebSuggestions = false;
            SponsoredSuggestions = false;
            ImproveSuggest = false;
            Locked = true;
          };
          HardwareAcceleration = false; # Exposes points for fingerprinting
          Homepage = {
            URL = "https://daily.dev";
            Locked = true;
            StartPage = "homepage";
          };
          HttpsOnlyMode = "force_enabled";
          NoDefaultBookmarks = true;
          OfferToSaveLogins = false;
          OverrideFirstRunPage = "";
          OverridePostUpdatePage = "";
          DontCheckDefaultBrowser = true;
          PasswordManagerEnabled = false;
          PDFjs = {
            Enabled = false;
            EnablePermissions = false;
          };
          PictureInPicture = lock-true;
          SanitizeOnShutdown = {
            Cache = true;
            Cookies = false;
            Downloads = true;
            FormData = true;
            History = false;
            Sessions = false;
            SiteSettings = false;
            OfflineApps = true;
            Locked = true;
          };
          SearchBar = "unified";
          SearchEngines = {
            Remove = [
              "Amazon.com"
              "Bing"
              "Google"
            ];
            Default = "DuckDuckGo";
            DefaultPrivate = "DuckDuckGo";
          };
          SearchSuggestEnabled = false;
          ShowHomeButton = false;
          StartDownloadsInTempDirectory = true;
          TranslateEnabled = true;
          UserMessaging = {
            ExtensionRecommendations = false;
            FeatureRecommendations = false;
            MoreFromMozilla = false;
            SkipOnbording = true;
            UrlbarInterventions = false;
            WhatsNew = false;
            Locked = true;
          };

          # --- EXTENSIONS ---
          # about:support#addons
          ExtensionSettings =
            with builtins;
            let
              extension = shortId: uuid: {
                name = uuid;
                value = {
                  install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
                  installation_mode = "normal_installed";
                };
              };
            in
            listToAttrs [
              (extension "ublock-origin" "uBlock0@raymondhill.net")
              (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
              (extension "1password-x-password-manager" "{d634138d-c276-4fc8-924b-40a0ea21d284}")
              (extension "facebook-container" "@contain-facebook")
              (extension "code-finder-catalyzex" "{a3f8e50c-bc39-4e48-ae2f-2ed36fa6752b}")
              (extension "arxiv-vanity" "{e92bf629-488c-4d5f-8771-04812b17c143}")
              (extension "auto-tab-discard" "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}")
              (extension "dearrow" "deArrow@ajay.app")
              (extension "disable-twitch-extensions" "disable-twitch-extensions@rootonline.de")
              (extension "enhancer-for-youtube" "enhancerforyoutube@maximerf.addons.mozilla.org")
              (extension "private-relay" "private-relay@firefox.com")
              (extension "gnu_terry_pratchett" "jid1-HGPgB0x6133Hig@jetpack")
              (extension "imagus" "{00000f2a-7cde-4f20-83ed-434fcb420d71}")
              (extension "old-reddit-redirect" "{9063c2e9-e07c-4c2c-9646-cfe7ca8d0498}")
              (extension "skip-redirect" "skipredirect@sblask")
              (extension "sponsorblock" "sponsorBlocker@ajay.app")
              (extension "unpaywall" "{f209234a-76f0-4735-9920-eb62507a54cd}")
              (extension "vimium-ff" "{d7742d87-e61d-4b78-b8a1-b469842139fa}")
            ];

          # --- PREFERENCES ---
          # Check about:config for options
          # https://avoidthehack.com/firefox-privacy-config
          # https://privacysavvy.com/security/safe-browsing/firefox-privacy-security-ultimate-guide/
          # https://allaboutcookies.org/firefox-privacy-settings
          Preferences = {
            "extensions.pocket.enabled" = lock-false;
            "extensions.screenshots.disabled" = lock-true;
            "extensions.formautofill.addresses.enabled" = lock-false;
            "browser.topsites.contile.enabled" = lock-false;
            "browser.formfill.enable" = lock-false;
            "browser.search.suggest.enabled" = lock-false;
            "browser.search.suggest.enabled.private" = lock-false;
            "browser.urlbar.suggest.searches" = lock-false;
            "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
            "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
            "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
            "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
            "browser.newtabpage.activity-stream.showSponsored" = lock-false;
            "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
            "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;
            "privacy.trackingprotection.socialtracking.enabled" = lock-true;
            "privacy.donottrackheader.enabled" = lock-true;
            "media.peerconnection.enabled" = lock-false;
            "geo.enabled" = lock-false;
            "network.cookie.cookieBehavior" = 4; # Cookie Jar
            "media.navigator.enabled" = lock-false;
            "dom.event.clipboardevents.enabled" = lock-false;
            "privacy.globalprivacycontrol.enabled" = lock-true;
            "privacy.fingerprintingProtection" = lock-true;
            "privacy.resistFingerprinting" = lock-true;
            "privacy.firstparty.isolate" = lock-true;
            "browser.send_pings" = lock-false;
            "beacon.enabled" = lock-false;
            "privacy.bounceTrackingProtection.mode" = 1;

            "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = lock-true;
            "sidebar.verticalTabs" = true;
            "sidebar.revamp" = true;
            "sidebar.backupState" = {
              "command" = "";
              "launcherExpanded" = false;
              "launcherVisible" = false;
            };
            "sidebar.visibility" = "always-show";

            "network.http.referer.XOriginPolicy" = 1;
            "network.http.referer.XOriginTrimmingPolicy" = 2;
            "browser.urlbar.speculativeConnect.enabled" = lock-false;
            "network.dns.disablePrefetch" = lock-true;
            "network.predictor.enabled" = lock-false;
            "network.prefetch-next" = lock-false;
            "cookiebanners.service.mode.privateBrowsing" = 1;
          };
        };
      };
    };
  };
}
