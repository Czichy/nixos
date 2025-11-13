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
  enteAccountsDomain = "photos-accounts.${globals.domains.me}";
  enteAlbumsDomain = "photos-albums.${globals.domains.me}";
  enteApiDomain = "photos-api.${globals.domains.me}";
  enteCastDomain = "photos-cast.${globals.domains.me}";
  entePhotosDomain = "photos.${globals.domains.me}";
  s3Domain = "photos-s3.${globals.domains.me}";

  # SELECT * from users;
  admin_id = "1580559962386438";

  certloc = "/var/lib/acme-sync/czichy.com";
in {
  networking.hostName = "HL-3-RZ-ENTE-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [8080 9000 9001];
    allowedUDPPorts = [8080 9000 9001];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
            # Wichtige Einstellung: Deaktiviert die TLS-Zertifikatsprüfung
          	tls_server_name ${enteApiDomain}
          }
      }
      import czichy_headers
    '';
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
          	tls_server_name ${s3Domain}
          }
      }
      import czichy_headers
    '';
  };
  #   services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
  #     reverse_proxy https://10.15.70.1:443 {
  #         transport http {
  #         	tls_server_name ${enteApiDomain}
  #         }
  #     }
  #     tls ${certloc}/cert.pem ${certloc}/key.pem {
  #       protocols tls1.3
  #     }
  #     import czichy_headers
  #   '';
  #   services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
  #     reverse_proxy https://10.15.70.1:443 {
  #         transport http {
  #         	tls_server_name ${s3Domain}
  #         }
  #     }
  #     tls ${certloc}/cert.pem ${certloc}/key.pem {
  #       protocols tls1.3
  #     }
  #     import czichy_headers
  #   '';
  # };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:8080 {
          }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:9000 {
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.ente.domain = entePhotosDomain;
  # FIXME: also monitor from internal network
  globals.monitoring.http.ente = {
    url = "https://${entePhotosDomain}";
    expectedBodyRegex = "Ente Photos";
    network = "internet";
  };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/minio";
      user = "minio";
      group = "minio";
      mode = "0750";
    }
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/ente";
      user = "ente";
      group = "ente";
      mode = "0750";
    }
    {
      directory = "/var/lib/postgresql";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.s3-ente-access-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/ente-access-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.s3-ente-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/ente-secret-key.age";
    mode = "440";
    group = "ente";
  };
  # |----------------------------------------------------------------------| #
  age.secrets.minio-access-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-access-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-secret-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-root-credentials = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
    mode = "440";
    group = "minio";
  };

  # base64 (url)
  age.secrets.ente-jwt = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-jwt.age";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-encryption-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-encryption-key.age";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-hash-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-hash-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.ente-local = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-local.age";
    mode = "440";
    group = "ente";
  };
  # age.secrets.ente-smtp-password = {
  #   file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
  #   mode = "440";
  #   group = "ente";
  # };
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.restic-postgres = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/restic-postgres.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.restic-minio = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/restic-minio.age";
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };

  age.secrets.postgres-hc-ping = {
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
    environment.MINIO_SERVER_URL = "https://${s3Domain}";
    postStart = ''
      # Wait until minio is up
      ${lib.getExe pkgs.curl} --retry 5 --retry-connrefused --fail --no-progress-meter -o /dev/null "http://localhost:9000/minio/health/live"

      # Make sure bucket exists
      mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/ente
    '';
  };

  systemd.services.ente.after = ["minio.service"];
  services.ente.api = {
    enable = true;
    enableLocalDB = true;
    domain = enteApiDomain;
    settings = {
      apps = {
        accounts = "https://${enteAccountsDomain}";
        cast = "https://${enteCastDomain}";
        public-albums = "https://${enteAlbumsDomain}";
      };

      webauthn = {
        rpid = enteAccountsDomain;
        rporigins = ["https://${enteAccountsDomain}"];
      };

      # FIXME: blocked on https://github.com/ente-io/ente/issues/5958
      # smtp = {
      #   host = config.repo.secrets.local.ente.mail.host;
      #   port = 465;
      #   email = config.repo.secrets.local.ente.mail.from;
      #   username = config.repo.secrets.local.ente.mail.user;
      #   password._secret = config.age.secrets.ente-smtp-password.path;
      # };
      s3 = {
        use_path_style_urls = true;
        b2-eu-cen = {
          endpoint = "http://10.15.40.19:9000";
          region = "garage";
          bucket = "ente";
          key._secret = config.age.secrets.s3-ente-secret-key.path;
          secret._secret = config.age.secrets.s3-ente-access-key.path;
        };
        # b2-eu-cen = {
        #   endpoint = "https://${s3Domain}";
        #   region = "germany-frankfurt-1";
        #   bucket = "ente";
        #   key._secret = config.age.secrets.minio-access-key.path;
        #   secret._secret = config.age.secrets.minio-secret-key.path;
        # };
      };

      jwt.secret._secret = config.age.secrets.ente-jwt.path;
      local-yaml = config.age.secrets.ente-local.path;
      key = {
        encryption._secret = config.age.secrets.ente-encryption-key.path;
        hash._secret = config.age.secrets.ente-hash-key.path;
      };

      internal = {
        admin = admin_id;
      };
    };
  };

  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    minio_backup_dir = lib.map (dir: "${dir}/ente") config.services.minio.dataDir;
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.postgres-hc-ping.path})"
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
    ente-postgres-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-ente-postgres";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["/tmp/postgresql-dump.sql.gz"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-postgres.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run before starting the backup process.
      backupPrepareCommand =
        /*
        sh
        */
        ''
          ${config.services.postgresql.package}/bin/pg_dumpall --clean \
          | ${lib.getExe pkgs.gzip} --rsyncable \
          > /tmp/postgresql-dump.sql.gz
        '';

      # A script that must run after finishing the backup process.
      backupCleanupCommand =
        /*
        sh
        */
        ''
          rm /tmp/postgresql-dump.sql.gz
        '';

      # Extra extended options to be passed to the restic --option flag.
      # extraOptions = [];

      # Extra arguments passed to restic backup.
      # extraBackupArgs = [
      #   "--exclude-file=/etc/restic/excludes-list"
      # ];

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
        OnCalendar = "*-*-* 02:30:00";
      };
    };
    ente-minio-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-ente-minio";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = minio_backup_dir;

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-postgres.path;
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

  # NOTE: services.ente.web is configured separately on both proxy servers!
  # nodes.sentinel.services.nginx = proxyConfig config.wireguard.proxy-sentinel.ipv4 "";
  # nodes.ward-web-proxy.services.nginx = proxyConfig config.wireguard.proxy-home.ipv4 ''
  #   allow ${globals.net.home-lan.vlans.home.cidrv4};
  #   allow ${globals.net.home-lan.vlans.home.cidrv6};
  #   # Firezone traffic
  #   allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
  #   allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
  #   deny all;
  # '';
}
