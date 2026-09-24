{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  dataDir = "${homeDir}/.beads/shared-server/dolt";
  port = 3308;
in {
  config = {
    home.activation.ensureBeadsSharedServer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${dataDir}"

      # Bootstrap beads_global on the shared dolt server.
      # Start a transient dolt instance (launchd hasn't started yet),
      # create the database, init beads schema, then stop it.
      if ! ${pkgs.dolt}/bin/dolt --host 127.0.0.1 --port ${toString port} --user root --password "" --no-tls \
           sql -q "SELECT 1 FROM beads_global.metadata LIMIT 1" >/dev/null 2>&1; then
        ${pkgs.dolt}/bin/dolt sql-server --data-dir "${dataDir}" \
          -H 127.0.0.1 -P ${toString port} -l error &
        _dolt_pid=$!
        sleep 2
        ${pkgs.dolt}/bin/dolt --host 127.0.0.1 --port ${toString port} --user root --password "" --no-tls \
          sql -q "CREATE DATABASE IF NOT EXISTS beads_global;" 2>/dev/null || true
        BEADS_DIR="${homeDir}/.beads" BEADS_DOLT_SHARED_SERVER=1 \
          ${pkgs.beads}/bin/bd --global init --shared-server --external --non-interactive \
            --skip-hooks --skip-agents --reinit-local 2>/dev/null || true
        kill $_dolt_pid 2>/dev/null || true
        wait $_dolt_pid 2>/dev/null || true
      fi
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
