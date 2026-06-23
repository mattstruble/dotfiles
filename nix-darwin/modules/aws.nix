{ config, lib, ... }:

let
  cfg = config.programs.aws;

  ssoSessionModule = { name, ... }: {
    options = {
      ssoStartUrl = lib.mkOption {
        type = lib.types.str;
        description = "SSO start URL for this session.";
      };
      ssoRegion = lib.mkOption {
        type = lib.types.str;
        description = "AWS region for SSO authentication.";
      };
      ssoRegistrationScopes = lib.mkOption {
        type = lib.types.str;
        default = "sso:account:access";
        description = "SSO registration scopes.";
      };
    };
  };

  profileModule = { name, ... }: {
    options = {
      ssoSession = lib.mkOption {
        type = lib.types.str;
        description = "Name of the sso-session to use.";
      };
      accountId = lib.mkOption {
        type = lib.types.str;
        description = "AWS account ID.";
      };
      roleName = lib.mkOption {
        type = lib.types.str;
        description = "IAM role name to assume via SSO.";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default AWS region. Omitted from config if empty.";
      };
      output = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Default output format. Omitted from config if empty.";
      };
      extraConfig = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Additional key=value entries for this profile block.";
      };
    };
  };

  # Render a single profile block
  renderProfile = name: p:
    let
      optionalLine = key: val:
        lib.optionalString (val != "") "${key} = ${val}\n";
      extraLines = lib.concatStrings
        (lib.mapAttrsToList (k: v: "${k} = ${v}\n") p.extraConfig);
      block =
        "[profile ${name}]\n"
        + "sso_session = ${p.ssoSession}\n"
        + "sso_account_id = ${p.accountId}\n"
        + "sso_role_name = ${p.roleName}\n"
        + optionalLine "region" p.region
        + optionalLine "output" p.output
        + extraLines;
    in
      # Warn if ssoSession references a session not declared in this module
      lib.warnIf
        (! builtins.hasAttr p.ssoSession cfg.ssoSessions)
        "programs.aws: profile '${name}' references sso_session '${p.ssoSession}' which is not defined in programs.aws.ssoSessions"
        block;

  # Render a single sso-session block
  renderSession = name: s:
    "[sso-session ${name}]\n"
    + "sso_start_url = ${s.ssoStartUrl}\n"
    + "sso_region = ${s.ssoRegion}\n"
    + "sso_registration_scopes = ${s.ssoRegistrationScopes}\n";

  # Sort attrset keys for deterministic output
  sortedProfiles = builtins.sort (a: b: a < b) (builtins.attrNames cfg.profiles);
  sortedSessions = builtins.sort (a: b: a < b) (builtins.attrNames cfg.ssoSessions);

  configText =
    lib.concatStringsSep "\n" (map (n: renderProfile n cfg.profiles.${n}) sortedProfiles)
    + "\n"
    + lib.concatStringsSep "\n" (map (n: renderSession n cfg.ssoSessions.${n}) sortedSessions);
in
{
  options.programs.aws = {
    enable = lib.mkEnableOption "AWS CLI config generation";

    ssoSessions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ssoSessionModule);
      default = {};
      description = "SSO sessions keyed by session name.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule profileModule);
      default = {};
      description = "AWS profiles keyed by profile name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".aws/config".text = configText;
  };
}
