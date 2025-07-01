{
  config,
  globals,
  secretsPath,
  hostName,
  pkgs,
  ...
}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
  microvm.mem = 512;
  microvm.vcpu = 1;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;

  networking.firewall = {
    allowedTCPPorts = [443 1880];
  };
  # |----------------------------------------------------------------------| #
  age.secrets.restic-node-red = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/node-red/restic-node-red.age";
    mode = "440";
  };

  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };

  age.secrets.node-red-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # |----------------------------------------------------------------------| #

  services.node-red = {
    enable = true;
    withNpmAndGcc = true;
    define = {"editorTheme.projects.enabled" = "true";};
  };

  # |----------------------------------------------------------------------| #
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.node-red-hc-ping.path})"
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
    node-red-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-node-red";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["/var/lib/node-red"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-node-red.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "node-red";

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
        OnCalendar = "*-*-* 01:30:00";
      };
    };
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/var/lib/node-red";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #
  # topology.self.services.powermeter = {
  # info = "https://" + unifiDomain;
  # name = "Power Meter";
  # };
  # |----------------------------------------------------------------------| #
}
