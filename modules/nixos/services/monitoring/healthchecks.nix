{
  localFlake,
  secretsPath,
}: {
  globals,
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkImpermanenceEnableOption
    isModuleLoadedAndEnabled
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.services.monitoring.healthchecks;
  port = 45566;
  host = "health.czichy.com";
  certloc = "/var/lib/acme/czichy.com";

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.services.monitoring.healthchecks = with types; {
    enable = mkEnableOption ''healthchecks self-hosted monitoring tool'';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      globals.services.healthchecks.domain = host;
      topology.self.services.healthchecks = let
        address = config.services.healthchecks.settings.SITE_ROOT null;
        port = config.services.healthchecks.port or null;
      in {
        name = "Healthchecks";
        # icon = "services.uptime-kuma";
        info = "${host}";
        details.listen = mkIf (address != null && port != null) {text = "${address}:${toString port}";};
      };
    }
    # |----------------------------------------------------------------------| #
    {
      services.healthchecks = {
        enable = true;
        listenAddress = "0.0.0.0";
        inherit port;
        dataDir = "/services/healthchecks";
        settings = {
          SECRET_KEY_FILE = config.age.secrets.healthchecks.path;
          SITE_ROOT = "host";
          EMAIL_HOST = "localhost";
          EMAIL_PORT = "25";
          EMAIL_USE_TLS = "False";
        };
      };
      # |----------------------------------------------------------------------| #
      networking.firewall.allowedTCPPorts = [80 port];
      # |----------------------------------------------------------------------| #
      users = {
        users.healthchecks = {
          isSystemUser = true;
          group = "healthchecks";
        };
        groups.healthchecks = {};
      };
    }
    # |----------------------------------------------------------------------| #
    (lib.mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [
          {
            directory = "${config.services.healthchecks.dataDir}";
            user = "healthchecks";
            group = "healthchecks";
            mode = "0700";
          }
        ];
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets.healthchecks = {
        file = secretsPath + "/hosts/${hostName}/healthchecks.age";
        mode = "700";
        group = "healthchecks";
      };
      age.secrets.restic-healthchecks = {
        file = secretsPath + "/hosts/${hostName}/restic/healthchecks.age";
        mode = "700";
        group = "healthchecks";
      };

      age.secrets."hc-rclone.conf" = {
        file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
        mode = "700";
        group = "healthchecks";
      };

      age.secrets.hc-ntfy-alert-pass = {
        file = secretsPath + "/ntfy-sh/alert-pass.age";
        mode = "700";
        group = "healthchecks";
      };
    })
    # |----------------------------------------------------------------------| #
    {
      # TODO: configure private ip
      nodes.HL-4-PAZ-PROXY-01 = {
        services.caddy.virtualHosts."${host}".extraConfig = ''
            reverse_proxy localhost:${toString port}

            tls ${certloc}/cert.pem ${certloc}/key.pem {
              protocols tls1.3
            }
          import czichy_headers
        '';
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
      services.restic.backups = let
        ntfy_pass = "$(cat ${config.age.secrets.hc-ntfy-alert-pass.path})";
        ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
        uptime-kuma_url = "https://uptime.czichy.com/api/push/6BclrdyqLe?status=up&msg=OK&ping=";

        script-post = host: site: uptime_url: ''
          if [ $EXIT_STATUS -ne 0 ]; then
            ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} failed!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
          else
            ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} successful!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'
            ${pkgs.curl}/bin/curl '${uptime_url}'
          fi
        '';
      in {
        healthchecks-backup = {
          # Initialize the repository if it doesn't exist.
          initialize = true;

          # backup to a rclone remote
          repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-healthchecks";

          # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
          paths = [config.services.healthchecks.dataDir];

          # Patterns to exclude when backing up. See
          #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
          # for details on syntax.
          exclude = [];

          passwordFile = config.age.secrets.restic-healthchecks.path;
          rcloneConfigFile = config.age.secrets."hc-rclone.conf".path;

          # A script that must run before starting the backup process.
          backupPrepareCommand = ''
            echo "Building backup dir ${config.services.healthchecks.dataDir}"
            systemctl stop healthchecks.service
            systemctl stop healthchecks-sendalerts.service
            systemctl stop healthchecks-sendreports.service
          '';

          # A script that must run after finishing the backup process.
          backupCleanupCommand =
            ''
              systemctl start healthchecks.target
            ''
            + script-post config.networking.hostName "healthchecks" uptime-kuma_url;

          # A list of options (--keep-* et al.) for 'restic forget --prune',
          # to automatically prune old snapshots.
          # The 'forget' command is run *after* the 'backup' command, so
          # keep that in mind when constructing the --keep-* options.
          pruneOpts = [
            "--keep-daily 3"
            "--keep-weekly 3"
            "--keep-monthly 3"
            "--keep-yearly 3"
          ];

          # When to run the backup. See {manpage}`systemd.timer(5)` for details.
          timerConfig = {
            OnCalendar = "*-*-* 00:45:00";
          };
        };
      };
    }
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
