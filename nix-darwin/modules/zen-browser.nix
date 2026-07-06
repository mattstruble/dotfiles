{ inputs, pkgs, ... }:

# Extensions deliberately NOT included (redundant with AdNauseam + arkenfox + AdGuard Home):
# - ClearURLs (uBlock/AdNauseam handles URL parameter stripping)
# - Random User Agent (fingerprintingProtection already spoofs UA)
# - TrackMeNot (makes you more unique, not less)
# - Spoof Geolocation (geo.enabled = false covers this)
# - Skip Redirect (AdNauseam + ClearURLs built-in handles this)
# - Private Relay (Mozilla service, not relevant for Zen)

{
  imports = [ inputs.zen-browser.homeModules.beta ];

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

        # --- DNS: network-level AdGuard Home handles this; DoH is redundant ---
        "network.trr.mode" = 5; # 5 = disabled (off, use OS resolver)

        # --- WebRTC: disabled on personal machine; work host re-enables ---
        "media.peerconnection.enabled" = false;

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
    };
  };
}
