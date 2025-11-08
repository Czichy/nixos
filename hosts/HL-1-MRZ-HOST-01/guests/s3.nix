{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  ...
}:
# NOTE: To increase storage for all users:
#  $ runuser -u ente -- psql
#  ente => UPDATE subscriptions SET storage = 6597069766656;
# get One Time Password for user registration
# journalctl -au ente | grep SendEmailOTT | tail -n 1
let
  s3Domain = "s3.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";
in {
  networking.hostName = "HL-3-RZ-S3-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [9000 9001];
    allowedUDPPorts = [9000 9001];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
            # Wichtige Einstellung: Deaktiviert die TLS-Zertifikatsprüfung
          	tls_server_name ${s3Domain}
          }
      }
      import czichy_headers
    '';
  };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-S3-01".ipv4}:9000 {
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.s3.domain = s3Domain;
  # FIXME: also monitor from internal network
  # globals.monitoring.http.ente = {
  #   url = "https://${entePhotosDomain}";
  #   expectedBodyRegex = "Ente Photos";
  #   network = "internet";
  # };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/minio";
      user = "minio";
      group = "minio";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.minio-access-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-access-key.age";
    mode = "440";
    group = "parseable";
  };
  age.secrets.minio-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-secret-key.age";
    mode = "440";
    group = "parseable";
  };
  age.secrets.minio-root-credentials = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-root-credentials.age";
    mode = "440";
    group = "minio";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "minio";
  };
  # |----------------------------------------------------------------------| #
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.restic-minio = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/restic-minio.age";
    mode = "440";
  };

  age.secrets.minio-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  services.minio = {
    enable = true;
    rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
    region = "germany-frankfurt-1";
  };
  systemd.services.minio = {
    environment.MINIO_SERVER_URL = "http://10.15.40.19:9000";
    # environment.MINIO_SERVER_URL = "https://${s3Domain}";
    postStart = ''
      # Wait until minio is up
      ${lib.getExe pkgs.curl} --retry 5 --retry-connrefused --fail --no-progress-meter -o /dev/null "http://localhost:9000/minio/health/live"

      # Make sure bucket exists
      mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/parseable
      mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/ente
    '';
  };

  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    minio_backup_dir = lib.map (dir: "${dir}/ente") config.services.minio.dataDir;
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.minio-hc-ping.path})"
      if [ $EXIT_STATUS -ne 0 ]; then
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
        -H 'Title: Backup (${site}) on ${host} failed!' \
        -H 'Tags: backup,restic,${host},${site}' \
        -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}/fail"
      else
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}"
      fi
    '';
  in {
    ente-minio-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      # repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-ente-minio";
      repository = "rclone:onedrive_nas:/backup/HL-3-RZ-ENTE-01-ente-minio";
      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = minio_backup_dir;

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-minio.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run before starting the backup process.
      backupPrepareCommand = ''
      '';

      # A script that must run after finishing the backup process.
      backupCleanupCommand = ''
      '';

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
        OnCalendar = "*-*-* 02:45:00";
      };
    };
  };
}
