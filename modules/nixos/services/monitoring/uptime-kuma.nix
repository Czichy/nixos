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

  cfg = config.tensorfiles.services.monitoring.uptime-kuma;
  uptime-port = "8095";
  uptime-host = "uptime.czichy.com";
  certloc = "/var/lib/acme/czichy.com";

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.services.monitoring.uptime-kuma = with types; {
    enable = mkEnableOption ''uptime-kuma self-hosted monitoring tool'';

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
      globals.services.uptime-kuma.domain = uptime-host;
      topology.self.services.uptime-kuma = let
        address = config.services.uptime-kuma.settings.HOST or null;
        port = config.services.uptime-kuma.settings.PORT or null;
      in {
        name = "Uptime-Kuma";
        icon = "services.uptime-kuma";
        info = "${uptime-host}";
        details.listen = mkIf (address != null && port != null) {text = "${address}:${toString port}";};
      };
    }
    # |----------------------------------------------------------------------| #
    {
      services.uptime-kuma = {
        enable = true;
        settings = {
          PORT = toString uptime-port;
          DATA_DIR = "/var/lib/uptime-kuma/";
        };
      };

      users = {
        users.uptime-kuma = {
          isSystemUser = true;
          group = "uptime-kuma";
        };
        groups.uptime-kuma = {};
      };
    }
    # |----------------------------------------------------------------------| #
    # tmpfiles to create shares if not yet present
    {
      # systemd.tmpfiles.settings = {
      #   "10-uptime-kuma" = {
      #     "/var/lib/private" = {
      #       d = {
      #         mode = "0700";
      #       };
      #     };
      #   };
      # };
    }
    # |----------------------------------------------------------------------| #
    (lib.mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [
          {
            directory = "/var/lib/uptime-kuma";
            user = "uptime-kuma";
            group = "uptime-kuma";
            mode = "0700";
          }
        ];
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets.restic-uptime-kuma = {
        file = secretsPath + "/hosts/${hostName}/restic/uptime-kuma.age";
        mode = "700";
        group = "uptime-kuma";
      };

      age.secrets."rclone.conf" = {
        file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
        mode = "700";
        group = "uptime-kuma";
      };

      age.secrets.ntfy-alert-pass = {
        file = secretsPath + "/ntfy-sh/alert-pass.age";
        mode = "700";
        group = "uptime-kuma";
      };
      age.secrets.uptime-hc-ping = {
        file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
        mode = "700";
        group = "uptime-kuma";
      };
    })
    # |----------------------------------------------------------------------| #
    {
      # TODO: configure private ip
      nodes.HL-4-PAZ-PROXY-01 = {
        services.caddy.virtualHosts."${uptime-host}".extraConfig = ''
            reverse_proxy localhost:${uptime-port}

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
        ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
        ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
        pingKey = "$(cat ${config.age.secrets.samba-hc-ping.path})";
        slug = "https://health.czichy.com/ping/${pingKey}";

        script-post = host: site: ''
          if [ $EXIT_STATUS -ne 0 ]; then
            ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} failed!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
            ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/backup-${site}/fail"
          else
            ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} successful!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'
            ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/backup-${site}"
          fi
        '';
      in {
        uptime-kuma-backup = {
          # Initialize the repository if it doesn't exist.
          initialize = true;

          # backup to a rclone remote
          repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-uptime-kuma";

          # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
          paths = ["${impermanence.persistentRoot}/${config.services.uptime-kuma.settings.DATA_DIR}"];

          # Patterns to exclude when backing up. See
          #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
          # for details on syntax.
          exclude = [];

          passwordFile = config.age.secrets.restic-uptime-kuma.path;
          rcloneConfigFile = config.age.secrets."rclone.conf".path;

          # A script that must run before starting the backup process.
          backupPrepareCommand = ''
            echo "Building backup dir ${config.services.uptime-kuma.settings.DATA_DIR}"
            systemctl stop uptime-kuma
          '';

          # A script that must run after finishing the backup process.
          backupCleanupCommand =
            ''
              systemctl start uptime-kuma
            ''
            + script-post config.networking.hostName "uptime-kuma";

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
            OnCalendar = "*-*-* 00:30:00";
          };
        };
      };
    }
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
