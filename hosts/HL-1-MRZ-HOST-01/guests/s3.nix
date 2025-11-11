{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  ...
}:
# Garage S3-compatible object storage
# Documentation: https://garagehq.deuxfleurs.fr/
#
# To enable this service:
# 1. Generate RPC secret: openssl rand -hex 32
# 2. Add to 1password for use via opnix
# 3. Enable this module in hosts/nas/default.nix
# 4. Run: sudo nixos-rebuild switch --flake .#nas
# 5. Initialize cluster:
#    garage status
#    garage layout assign <node-id> -c 500G -z default
#    garage layout apply --version 1
# 6. Create buckets and keys:
#    garage bucket create my-bucket
#    garage key create my-key
#    garage bucket allow --read --write my-bucket --key my-key
# Data Migration from MinIO
# # Configure both endpoints
# mc alias set minio http://10.0.7.7:9000 <minio-access-key> <minio-secret-key>
# mc alias set garage http://10.0.7.7:3900 <garage-access-key> <garage-secret-key>
# # Migrate data
# mc mirror minio/bucket-name garage/bucket-name
# Set an expiration policy (using the aws CLI):
# aws s3api put-bucket-lifecycle-configuration \
#         --endpoint-url http://127.0.0.1:3900 \
#         --bucket talos-backup \
#         --lifecycle-configuration '{
#       "Rules": [
#         {
#           "ID": "30-day-expiration",
#           "Status": "Enabled",
#           "Expiration": {
#             "Days": 30
#           }
#         }
#       ]
#     }'
let
  s3Domain = "s3.${globals.domains.me}";
  apiPort = 9000;
  rpcPort = 3901;
  webPort = 3902;
  adminPort = 3903;

  certloc = "/var/lib/acme-sync/czichy.com";
in {
  networking.hostName = "HL-3-RZ-S3-01";
  # |----------------------------------------------------------------------| #
  # open firewall ports
  networking.firewall = {
    allowedTCPPorts = [apiPort webPort];
    # allowedUDPPorts = [9000 9001];
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
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-S3-01".ipv4}:${toString apiPort} {
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
    # };
    # nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."s3-web.czichy.com".extraConfig = ''
      reverse_proxy http://s3-web.czichy.com:${toString webPort}{
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #

  # globals.services.s3.domain = s3Domain;
  # FIXME: also monitor from internal network
  # globals.monitoring.http.ente = {
  #   url = "https://${entePhotosDomain}";
  #   expectedBodyRegex = "Ente Photos";
  #   network = "internet";
  # };

  # Create explicit garage user and group (not DynamicUser)
  # Add nix user to garage group for CLI access to secrets
  users = {
    users.garage = {
      isSystemUser = true;
      group = "garage";
    };
    groups.garage = {};
  };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/garage";
      user = "garage";
      group = "garage";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.rpc-secret = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/rpc-secret.age";
    mode = "600";
    owner = "garage";
    group = "garage";
  };
  age.secrets.admin_token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/admin-token.age";
    mode = "600";
    owner = "garage";
    group = "garage";
  };
  age.secrets.metrics_token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/metrics-token.age";
    mode = "600";
    owner = "garage";
    group = "garage";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "600";
    group = "garage";
  };
  # |----------------------------------------------------------------------| #
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "600";
    group = "garage";
  };
  age.secrets.restic-minio = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/restic-minio.age";
    mode = "600";
  };

  age.secrets.minio-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  #  # Add garage CLI and Web UI to system packages for management
  # environment.systemPackages = with pkgs; [
  #   garage_2
  #   garage-webui
  # ];

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    #environmentFile = /etc/garage.toml;
    logLevel = "debug";
    settings = {
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/var/lib/garage/data";

      rpc_bind_addr = "127.0.0.1:${toString rpcPort}";
      # rpc_public_addr = "http://${globals.net.vlan40.hosts."HL-3-RZ-S3-01".ipv4}:${rpcPort}";
      rpc_secret_file = config.age.secrets.rpc-secret.path;

      # node identity (must be unique per node)
      node_name = config.networking.hostName;

      db_engine = "sqlite";
      replication_factor = 1;

      # cluster bootstrap
      #bootstrap_peers = []; # list other nodes' RPC URLs

      # Optional: S3 interface
      s3_api = {
        api_bind_addr = "127.0.0.1:${toString apiPort}";
        root_domain = s3Domain;
        s3_region = "garage";
      };

      s3_web = {
        bind_addr = "127.0.0.1:${toString webPort}";
        index = "index.html";
        root_domain = "s3-web.czichy.com";
      };

      # k2v_api = {
      #   api_bind_addr = "[::]:3904";
      # };

      admin = {
        api_bind_addr = "127.0.0.1:${toString adminPort}";
        admin_token_file = config.age.secrets.admin_token.path;
        metrics_token = config.age.secrets.metrics_token.path;
      };
    };
  };

  systemd.services.garage.serviceConfig = {
    DynamicUser = false;
    User = "garage";
    Group = "garage";
    ReadWriteDirectories = [config.services.garage.settings.data_dir];
    TimeoutSec = 300;
    # Allow group-readable secrets so nix user can access them for CLI
    Environment = [
      "CONFIG_PATH=/etc/garage.toml"
      "GARAGE_ALLOW_WORLD_READABLE_SECRETS=true"
    ];
  };

  # Optional Garage Web UI
  # Provides a web-based management UI for the Garage service.
  # This creates a simple systemd service that runs the `garage-webui` binary
  # from the `garage-webui` package and serves on TCP/3909 by default.
  # systemd.services.garage-webui = {
  #   # disabled until this works properly with garage2
  #   enable = false;
  #   description = "Garage Web UI";
  #   after = [
  #     "network.target"
  #     "garage.service"
  #   ];
  #   wantedBy = ["multi-user.target"];
  #   serviceConfig = {
  #     User = "garage";
  #     Group = "garage";
  #     Environment = [
  #       "CONFIG_PATH=/etc/garage.toml"
  #     ];
  #     ExecStart = "${pkgs.garage-webui}/bin/garage-webui";
  #     Restart = "on-failure";
  #   };
  #   path = with pkgs; [coreutils];
  # };

  # Use systemd.tmpfiles for directory management
  systemd.tmpfiles.rules = [
    # Create garage subdirectories with proper ownership and permissions
    "d ${config.services.garage.settings.data_dir} 0770 garage garage - -"
    "d ${config.services.garage.settings.metadata_dir} 0770 garage garage - -"
  ];

  # |----------------------------------------------------------------------| #
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
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
      paths = ["${config.services.garage.settings.data_dir}/ente"];

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
