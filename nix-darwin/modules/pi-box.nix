{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  json = pkgs.formats.json { };
  cfg = config.programs.pi-box;
  mcp = config.programs.pi-mcp.sandbox;

  nonEmpty = name: v: lib.optionalAttrs (v != [ ]) { ${name} = v; };

  # Per-session scratch: TMPDIR points into ~/.cache/pi-box/<session>, removed when the box closes.
  sessionDir = ''dir="$HOME/.cache/pi-box/''${NONO_SESSION_ID:?}"'';
  beforeHook = pkgs.writeShellScript "pi-box-before" ''
    ${sessionDir}
    mkdir -p "$dir/tmp"
    echo "TMPDIR=$dir/tmp" >> "$NONO_ENV_FILE"
  '';
  afterHook = pkgs.writeShellScript "pi-box-after" ''
    ${sessionDir}
    rm -rf "$dir"
  '';

  base = {
    extends = "default";
    meta = {
      name = "pi-base";
      description = "pi-box base profile";
    };
    groups.include = [
      "node_runtime"
      "rust_runtime"
      "python_runtime"
      "user_caches_macos"
      "nix_runtime"
      "git_config"
      "unlink_protection"
    ];
    workdir.access = "readwrite";
    filesystem =
      {
        allow = [
          "$HOME/.pi"
          "$HOME/llm-wiki"
          "$HOME/.beads"
          "$HOME/.local/share/pi"
          "$HOME/.config/pi"
          "$HOME/.cache/pi-box"
        ]
        ++ mcp.allow
        ++ cfg.filesystem.allow;
        allow_file = [ "$HOME/.beads.gate.lock" ];
        read = [
          cfg.piConfigDir
          "$HOME/.local/share/ponytail"
          "$HOME/.config/sops-nix/secrets"
        ]
        ++ mcp.secretPaths
        ++ cfg.filesystem.read;
      }
      // nonEmpty "bypass_protection" cfg.filesystem.bypassProtection
      // lib.optionalAttrs (cfg.onePasswordSocket != null) {
        unix_socket = [ cfg.onePasswordSocket ];
      };
    network = {
      open_port = cfg.localPorts;
    }
    // lib.optionalAttrs cfg.domainFiltering {
      allow_domain = lib.unique (mcp.domains ++ cfg.domains);
    };
    session_hooks = {
      before = {
        script = "${beforeHook}";
        timeout_secs = 10;
      };
      after = {
        script = "${afterHook}";
        timeout_secs = 30;
      };
    };
  };

  launcher = pkgs.writeShellApplication {
    name = "pi-box";
    runtimeInputs = [ cfg.package ];
    text = ''
      known=${lib.escapeShellArg (lib.concatStringsSep " " (lib.attrNames cfg.layers))}
      spec=''${PI_SANDBOX:-${lib.concatStringsSep "," cfg.defaultLayers}}
      [ -n "$spec" ] || spec=${lib.escapeShellArg (lib.concatStringsSep "," cfg.defaultLayers)}
      IFS=, read -r -a layers <<< "$spec"
      extends='"pi-base"'
      for l in "''${layers[@]}"; do
        case " $known " in
          *" $l "*) extends+=",\"$l\"" ;;
          *) echo "pi-box: unknown layer '$l'; known layers: $known" >&2; exit 1 ;;
        esac
      done
      name=$(IFS=-; echo "''${layers[*]}")
      dir=''${TMPDIR:-/tmp}/pi-box
      mkdir -p "$dir"
      printf '{"extends":[%s],"meta":{"name":"pi-box-%s"}}\n' "$extends" "$name" > "$dir/$name.json"
      exec nono run --profile "$dir/$name.json" --allow-cwd -- pi "$@"
    '';
  };
in
{
  options.programs.pi-box = {
    enable = lib.mkEnableOption "pi-box nono sandbox profiles";
    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.nono.packages.${pkgs.system}.prebuilt;
      description = "nono package.";
    };
    defaultLayers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "net-https" ];
      description = "Layer profiles the launcher composes by default.";
    };
    piConfigDir = lib.mkOption {
      type = lib.types.str;
      description = "Out-of-store directory pi's ~/.pi/agent files symlink into (read-only in the sandbox).";
    };
    onePasswordSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "1Password agent socket to allow, if any.";
    };
    domainFiltering = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Route network through nono's domain-filtering proxy. Disable on hosts whose
        clients dial out directly (e.g. the AWS SDK's SSO credential exchange); the
        filesystem fence still applies and the net-* layers then add nothing.
      '';
    };
    localPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        3308
        8008
      ];
      description = "Localhost ports the sandbox may connect to.";
    };
    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra model/API domains allowed by domain filtering.";
    };
    filesystem = {
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra read-write paths.";
      };
      read = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra read-only paths.";
      };
      bypassProtection = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths exempted from nono's protected-path deny list.";
      };
    };
    layers = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = "Layer profiles composed on top of pi-base via extends.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pi-box.layers = {
      net-none = {
        extends = [ "pi-base" ];
        meta = {
          name = "net-none";
          description = "pi-box: no network beyond pi-base";
        };
      };
      net-https = {
        extends = [ "pi-base" ];
        meta = {
          name = "net-https";
          description = "pi-box: registries, GitHub, docs";
        };
        network = lib.optionalAttrs cfg.domainFiltering { network_profile = "developer"; };
      };
    };

    home.packages = [
      cfg.package
      launcher
    ];

    xdg.configFile = {
      "nono/profiles/pi-base.json".source = json.generate "pi-base.json" base;
    }
    // lib.mapAttrs' (
      name: layer:
      lib.nameValuePair "nono/profiles/${name}.json" {
        source = json.generate "${name}.json" layer;
      }
    ) cfg.layers;
  };
}
