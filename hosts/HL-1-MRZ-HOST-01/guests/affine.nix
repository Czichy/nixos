{
  config,
  globals,
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
  affineDomain = "brain.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";
in
{
  # imports = [
  #   ./affine
  # ];

  microvm.mem = 1024 * 3;
  microvm.vcpu = 4;
  networking.hostName = "HL-3-RZ-AFFINE-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [ 3010 ];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${affineDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
            # Wichtige Einstellung: Deaktiviert die TLS-Zertifikatsprüfung
            # tls_insecure_skip_verify
          	tls_server_name ${affineDomain}
          }
          header_up Host {http.request.host}
      }
      import czichy_headers
    '';
  };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${affineDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-AFFINE-01".ipv4}:3010{
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.affine = {
    domain = affineDomain;
    homepage = {
      enable = true;
      name = "Affine";
      icon = "sh-affine";
      description = "Privacy-focused knowledge base with docs, whiteboards & databases";
      category = "Development & Collaboration";
      priority = 10;
      abbr = "AF";
    };
  };
  # |----------------------------------------------------------------------| #

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/affine";
      user = "affine";
      group = "affine";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };
  age.secrets.restic-affine = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/affine.age";
    mode = "440";
  };
  age.secrets.affine-ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };
  age.secrets.affine-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  age.secrets.hetzner-storage-box-ssh-key = {
    file = secretsPath + "/hetzner/storage-box/ssh_key.age";
    mode = "400";
  };
  # |----------------------------------------------------------------------| #
  services.affine = {
    enable = true;
    enableLocalDB = true;
    settings = {
      auth = {
        allowSignup = true;
        allowSignupForOauth = true;
        "session.ttl" = 365 * 86400; # ~1 year
      };
      server = {
        name = "Panzerbeere";
        host = "0.0.0.0";
        https = true;
        hosts = [
          "10.15.70.1"
        ];
        externalUrl = "https://${affineDomain}";
      };
    };
  };

  # |----------------------------------------------------------------------| #

  services.restic.backups =
    let
      ntfy_pass = "$(cat ${config.age.secrets.affine.ntfy-alert-pass.path})";
      ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
      # pingKey = "$(cat ${config.age.secrets.samba-hc-ping.path})";
      slug = "https://health.czichy.com/ping";

      script-post = host: site: ''
        pingKey="$(cat ${config.age.secrets.affine-hc-ping.path})";
          if [ $EXIT_STATUS -ne 0 ]; then
            ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} failed!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
            ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/$pingKey/backup-${site}/fail?create=1"
          else
            ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/$pingKey/backup-${site}?create=1"
          fi
      '';
      # ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
      # -H 'Title: Backup (${site}) on ${host} successful!' \
      # -H 'Tags: backup,restic,${host},${site}' \
      # -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'
    in
    {
      affine-backup = {
        # Initialize the repository if it doesn't exist.
        initialize = true;

        # backup to a rclone remote
        repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-affine";

        # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
        paths = [ "/var/lib/affine" ];

        # Patterns to exclude when backing up. See
        #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
        # for details on syntax.
        exclude = [ ];

        passwordFile = config.age.secrets.restic-dokumente.path;
        rcloneConfigFile = config.age.secrets."rclone.conf".path;

        backupCleanupCommand = script-post config.networking.hostName "affine";

        pruneOpts = [
          "--keep-daily 3"
          "--keep-weekly 3"
          "--keep-monthly 3"
          "--keep-yearly 3"
        ];

        timerConfig = {
          OnCalendar = "*-*-* 01:30:00";
        };
      };

      affine-backup-hetzner = {
        initialize = true;
        repository = "sftp:u581144@u581144.your-storagebox.de:/restic/${config.networking.hostName}-affine";
        paths = [ "/var/lib/affine" ];
        exclude = [ ];
        passwordFile = config.age.secrets.restic-affine.path;
        extraOptions = [
          "sftp.args='-i ${config.age.secrets.hetzner-storage-box-ssh-key.path} -o StrictHostKeyChecking=accept-new'"
        ];
        backupCleanupCommand = script-post config.networking.hostName "affine-hetzner";
        pruneOpts = [
          "--keep-daily 3"
          "--keep-weekly 3"
          "--keep-monthly 3"
          "--keep-yearly 3"
        ];
        timerConfig = {
          OnCalendar = "*-*-* 02:30:00";
        };
      };
    };

  # |----------------------------------------------------------------------| #
  tensorfiles.services.resticMaintenance = {
    enable = true;
    ntfyPassFile = config.age.secrets.affine-ntfy-alert-pass.path;
  };
}
