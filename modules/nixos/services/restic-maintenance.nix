{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.tensorfiles.services.resticMaintenance;

  # All restic backup jobs defined on this host/guest
  backupJobs = filterAttrs (
    _: job: job.repository != null || job.repositoryFile != null
  ) config.services.restic.backups;

  # Build the restic env vars for a job (repo + password + optional rclone config)
  jobEnv = job:
    {
      RESTIC_PASSWORD_FILE = job.passwordFile;
    }
    // optionalAttrs (job.repository != null) {
      RESTIC_REPOSITORY = job.repository;
    }
    // optionalAttrs (job.rcloneConfigFile != null) {
      RCLONE_CONFIG = job.rcloneConfigFile;
    };

  resticBin = "${pkgs.restic}/bin/restic";
  curlBin = "${pkgs.curl}/bin/curl";
  jqBin = "${pkgs.jq}/bin/jq";

  # Notification on failure
  notifyFail = name: ''
    HOST=$(${pkgs.hostname}/bin/hostname)
    NTFY_PASS=$(cat ${cfg.ntfyPassFile})
    ${curlBin} -s -o /dev/null \
      -u "alert:$NTFY_PASS" \
      -H "Title: Restic ${name} FAILED on $HOST" \
      -H "Tags: backup,restic,${name},$HOST" \
      -H "Priority: high" \
      -d "restic ${name} failed on $HOST — check journalctl -u restic-${name}-*.service" \
      "${cfg.ntfyUrl}" || true
  '';

  # ── Check service ────────────────────────────────────────────────────────
  mkCheckService = name: job:
    nameValuePair "restic-check-${name}" {
      description = "Restic integrity check for ${name} (monthly, 5 % data subset)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      environment = jobEnv job;
      # If repositoryFile is used (not repository), resolve it at runtime
      script =
        (optionalString (job.repository == null) ''
          export RESTIC_REPOSITORY="$(cat ${job.repositoryFile})"
        '')
        + ''
          set -euo pipefail

          echo "=== restic check ${name} ==="
          if ${resticBin} check --read-data-subset=5%; then
            echo "OK: restic check passed for ${name}"
          else
            ${notifyFail "check-${name}"}
            exit 1
          fi
        '';
    };

  # ── Restore-test service ─────────────────────────────────────────────────
  mkRestoreTestService = name: job:
    nameValuePair "restic-restore-test-${name}" {
      description = "Restic restore smoke-test for ${name} (monthly)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      environment = jobEnv job;
      script =
        (optionalString (job.repository == null) ''
          export RESTIC_REPOSITORY="$(cat ${job.repositoryFile})"
        '')
        + ''
          set -euo pipefail

          echo "=== restic restore-test ${name} ==="
          RESTORE_DIR=$(mktemp -d /tmp/restic-restore-${name}-XXXXXX)
          trap 'rm -rf "$RESTORE_DIR"' EXIT

          # Verify at least one snapshot exists
          SNAP=$(${resticBin} snapshots --json --last \
            | ${jqBin} -r 'if type=="array" then .[0].id else .id end // empty')

          if [ -z "$SNAP" ]; then
            echo "ERROR: no snapshots found for ${name}"
            ${notifyFail "restore-test-${name}"}
            exit 1
          fi
          echo "Latest snapshot: $SNAP"

          # Find the first regular file in the snapshot
          FIRST_FILE=$(${resticBin} ls --json "$SNAP" \
            | ${jqBin} -r 'select(.type=="file") | .path' \
            | head -1)

          if [ -z "$FIRST_FILE" ]; then
            echo "ERROR: snapshot $SNAP contains no files for ${name}"
            ${notifyFail "restore-test-${name}"}
            exit 1
          fi
          echo "Test file: $FIRST_FILE"

          # Restore that single file
          ${resticBin} restore "$SNAP" \
            --target "$RESTORE_DIR" \
            --include "$FIRST_FILE"

          # Verify restore dir is non-empty
          NFILES=$(find "$RESTORE_DIR" -type f | wc -l)
          if [ "$NFILES" -eq 0 ]; then
            echo "ERROR: restore produced 0 files for ${name}"
            ${notifyFail "restore-test-${name}"}
            exit 1
          fi

          echo "OK: restic restore-test passed for ${name} ($NFILES file(s) restored)"
        '';
    };

  # ── Timer factory ────────────────────────────────────────────────────────
  mkTimer = name: calendar:
    nameValuePair name {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = calendar;
        Persistent = true;
        # Spread jobs over 2 h to avoid thundering-herd against OneDrive
        RandomizedDelaySec = "2h";
      };
    };
in {
  options.tensorfiles.services.resticMaintenance = with types; {
    enable = mkEnableOption ''
      Monthly restic check (--read-data-subset=5%) and restore smoke-test timers
      for every job in services.restic.backups.
    '';

    ntfyPassFile = mkOption {
      type = path;
      description = "Path to file containing the ntfy alert password.";
    };

    ntfyUrl = mkOption {
      type = str;
      default = "https://ntfy.czichy.com/backups";
      description = "ntfy topic URL for failure notifications.";
    };

    checkCalendar = mkOption {
      type = str;
      default = "*-*-15 04:00:00";
      description = "OnCalendar expression for the monthly check timer (default: 15th).";
    };

    restoreCalendar = mkOption {
      type = str;
      default = "*-*-22 04:00:00";
      description = "OnCalendar expression for the monthly restore-test timer (default: 22nd).";
    };
  };

  config = mkIf cfg.enable {
    systemd.services =
      listToAttrs (mapAttrsToList mkCheckService backupJobs)
      // listToAttrs (mapAttrsToList mkRestoreTestService backupJobs);

    systemd.timers =
      listToAttrs (
        mapAttrsToList (name: _: mkTimer "restic-check-${name}" cfg.checkCalendar) backupJobs
      )
      // listToAttrs (
        mapAttrsToList (name: _: mkTimer "restic-restore-test-${name}" cfg.restoreCalendar) backupJobs
      );
  };

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
