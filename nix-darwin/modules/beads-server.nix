{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  dataDir = "${homeDir}/.local/share/beads-dolt";
  port = 3308;
in {
  config = {
    home.activation.ensureBeadsSharedServer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dataDir}"
      mkdir -p "${homeDir}/.beads/shared-server"
      printf %s ${toString port} > "${homeDir}/.beads/shared-server/dolt-server.port"
    '';

    launchd.agents.beads-dolt-server = {
      enable = true;
      config = {
        Label = "com.user.beads-dolt-server";
        ProgramArguments = [
          "${pkgs.dolt}/bin/dolt"
          "sql-server"
          "--data-dir" dataDir
          "-H" "127.0.0.1"
          "-P" (toString port)
          "-l" "warning"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${homeDir}/Library/Logs/beads-dolt-server.log";
        StandardErrorPath = "${homeDir}/Library/Logs/beads-dolt-server.log";
      };
    };
  };
}
