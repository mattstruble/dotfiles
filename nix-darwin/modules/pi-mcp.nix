{
  config,
  lib,
  pkgs,
  ...
}:

let
  json = pkgs.formats.json { };
  cfg = config.programs.pi-mcp;

  sandboxOf = s: s.sandbox or { };
  listOf' = name: s: (sandboxOf s).${name} or [ ];

  launcherOf =
    s:
    (sandboxOf s).launcher or (
      if s ? command then
        let
          b = baseNameOf s.command;
        in
        if b == "npx" || b == "uvx" then b else null
      else
        null
    );

  servers = lib.attrValues cfg.servers;
  withLauncher = l: lib.filter (s: launcherOf s == l) servers;

  urlHost =
    url:
    let
      m = builtins.match "[a-zA-Z][a-zA-Z0-9+.-]*://([^/:?#@]*@)?([^/:?#]+).*" url;
    in
    if m == null then null else lib.toLower (builtins.elemAt m 1);
in
{
  options.programs.pi-mcp = {
    servers = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = { };
      description = ''
        Servers for pi's built-in MCP support, rendered to ~/.pi/agent/mcp.json.
        An optional nix-only `sandbox` attribute (domains, allow, secrets, launcher)
        is stripped before rendering.
      '';
    };

    sandbox = {
      domains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        description = "Hostnames MCP servers need network access to.";
      };
      allow = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        description = "Filesystem paths MCP servers need access to.";
      };
      secretPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        description = "Secret paths declared by MCP servers.";
      };
    };
  };

  config = {
    programs.pi-mcp.sandbox = {
      domains = lib.unique (
        lib.concatMap (s: lib.optional (s ? url && urlHost s.url != null) (urlHost s.url)) servers
        ++ lib.concatMap (listOf' "domains") servers
        ++ lib.optional (withLauncher "npx" != [ ]) "registry.npmjs.org"
        ++ lib.optionals (withLauncher "uvx" != [ ]) [
          "pypi.org"
          "files.pythonhosted.org"
        ]
      );
      allow = lib.unique (
        lib.concatMap (listOf' "allow") servers
        ++ lib.optional (withLauncher "npx" != [ ]) "$HOME/.npm"
        ++ lib.optionals (withLauncher "uvx" != [ ]) [
          "$HOME/.local/share/uv"
          "$HOME/.cache/uv"
        ]
      );
      secretPaths = lib.unique (lib.concatMap (listOf' "secrets") servers);
    };

    # mcp.json is a read-only nix store symlink: use /mcp only to inspect and log in.
    # Exposure/enabled toggles and `pi mcp add` can't persist; change servers here.
    home.file.".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
      mcpServers = lib.mapAttrs (_: s: removeAttrs s [ "sandbox" ]) cfg.servers;
    };
  };
}
