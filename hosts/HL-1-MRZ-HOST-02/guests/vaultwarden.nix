{
  config,
  globals,
  secretsPath,
  pkgs,
  lib,
  ...
}: let
  vaultwardenDomain = "vault.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
  # backupPrepareScript = pkgs.writeShellApplication {
  #   name = "backup-prepare";
  #   runtimeInputs = [pkgs.home-assistant-cli];
  #   text = ''
  #     export HASS_SERVER=http://localhost:8123
  #     # shellcheck source=/dev/null
  #     # source "${hass-token}"
  #     hass-cli service call backup.create
  #   '';
  # };
in {
  # microvm.mem = 1024 * 2;
  # microvm.vcpu = 20;
  networking.hostName = "HL-3-RZ-VAULT-01";
  # |----------------------------------------------------------------------| #
  age.secrets.vaultwarden-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/vaultwarden/vaultwarden-env.age";
    mode = "440";
    group = "vaultwarden";
  };
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
    group = "vaultwarden";
  };
  age.secrets.restic-vaultwarden = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/vaultwarden/restic-vaultwarden.age";
    mode = "440";
    group = "vaultwarden";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "vaultwarden";
  };

  age.secrets.vaultwarden-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # |----------------------------------------------------------------------| #

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  # |----------------------------------------------------------------------| #
  globals.services.vaultwarden.domain = vaultwardenDomain;
  globals.monitoring.http.vaultwarden = {
    url = "https://${vaultwardenDomain}";
    expectedBodyRegex = "Vaultwarden Web";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [22 8012];
    allowedUDPPorts = [22 8012];
  };

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${vaultwardenDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${vaultwardenDomain}
            }
        }

        tls ${certloc}/cert.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${vaultwardenDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-VAULT-01".ipv4}:${toString config.services.vaultwarden.config.rocketPort}
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    # WARN: Careful! The backup script does not remove files in the backup location
    # if they were removed in the original location! Therefore, we use a directory
    # that is not persisted and thus clean on every reboot.
    backupDir = "/var/cache/vaultwarden-backup";
    config = {
      dataFolder = lib.mkForce "/var/lib/vaultwarden";
      extendedLogging = true;
      useSyslog = true;
      webVaultEnabled = true;

      rocketAddress = "0.0.0.0";
      rocketPort = 8012;

      signupsAllowed = false;
      passwordIterations = 1000000;
      invitationsAllowed = true;
      invitationOrgName = "Vaultwarden";
      domain = "https://${vaultwardenDomain}";

      smtpEmbedImages = true;
      smtpSecurity = "force_tls";
      smtpPort = 465;
    };
    # Admin secret token, see
    # https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page
    #ADMIN_TOKEN=...copy-paste a unique generated secret token here...
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };

  systemd.services.vaultwarden.serviceConfig = {
    StateDirectory = lib.mkForce "vaultwarden";
    RestartSec = "60"; # Retry every minute
  };
  # |----------------------------------------------------------------------| #
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";

  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.vaultwarden-hc-ping.path})"
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
    vaultwarden-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-vaultwarden";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = [config.services.vaultwarden.backupDir];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-vaultwarden.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run before starting the backup process.
      # backupPrepareCommand = ''
      #   echo "Building backup dir ${config.services.vaultwarden.backupDir}"
      #   mkdir -p ${config.services.vaultwarden.backupDir}
      #   ${pkgs.sqlite}/bin/sqlite3 ${config.services.vaultwarden.backupDir}/db.sqlite3 ".backup '${config.services.vaultwarden.backupDir}/vaultwarden.sqlite'"
      # '';

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "vaultwarden";

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
      pruneOpts = ["--keep-last 14"];

      # When to run the backup. See {manpage}`systemd.timer(5)` for details.
      timerConfig = {
        OnCalendar = "*-*-* 01:30:00";
      };
    };
  };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = config.services.vaultwarden.backupDir;
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  # |----------------------------------------------------------------------| #
  system.stateVersion = "24.05";
}
