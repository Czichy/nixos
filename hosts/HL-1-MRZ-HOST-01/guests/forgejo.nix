{
  config,
  globals,
  secretsPath,
  hostName,
  lib,
  pkgs,
  ...
}: let
  # |----------------------------------------------------------------------| #
  forgejoDomain = "git.${globals.domains.me}";

  certloc = "/var/lib/acme/czichy.com";
  # |----------------------------------------------------------------------| #
in {
  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  age.secrets.mailer-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/mailer-password.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  age.secrets.admin-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/admin-password.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  age.secrets.user-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/user-password.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  age.secrets.restic-forgejo = {
    file = secretsPath + "/hosts/HL-1-HOST-SBC-01/guests/forgejo/restic-forgejo.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  # |----------------------------------------------------------------------| #
  globals.services.forgejo.domain = forgejoDomain;
  globals.monitoring.http.vaultwarden = {
    url = "https://${forgejoDomain}/user/login";
    expectedBodyRegex = "Redlew Git";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  # nodes.sentinel = {
  #   # Rewrite destination addr with dnat on incoming connections
  #   # and masquerade responses to make them look like they originate from this host.
  #   # - 9922 (wan) -> 22 (proxy-sentinel)
  #   networking.nftables.chains = {
  #     postrouting.to-forgejo = {
  #       after = ["hook"];
  #       rules = [
  #         "iifname wan ip daddr ${config.wireguard.proxy-sentinel.ipv4} tcp dport 22 masquerade random"
  #         "iifname wan ip6 daddr ${config.wireguard.proxy-sentinel.ipv6} tcp dport 22 masquerade random"
  #       ];
  #     };
  #     prerouting.to-forgejo = {
  #       after = ["hook"];
  #       rules = [
  #         "iifname wan tcp dport 9922 dnat ip to ${config.wireguard.proxy-sentinel.ipv4}:22"
  #         "iifname wan tcp dport 9922 dnat ip6 to ${config.wireguard.proxy-sentinel.ipv6}:22"
  #       ];
  #     };
  #   };
  # };
  networking.firewall = {
    allowedTCPPorts = [
      config.services.forgejo.settings.server.HTTP_PORT
      config.services.forgejo.settings.server.SSH_PORT
    ];
  };
  # |----------------------------------------------------------------------| #

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${forgejoDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${forgejoDomain}
            }
        }

        tls ${certloc}/cert.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-SBC-01-caddy = {
    services.caddy = {
      virtualHosts."${forgejoDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-GIT-01".ipv4}:${toString config.services.forgejo.settings.server.HTTP_PORT}
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "git";
    home = config.services.forgejo.stateDir;
  };

  services.openssh = {
    authorizedKeysFiles = lib.mkForce [
      "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
    ];
    # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
    settings.AcceptEnv = "GIT_PROTOCOL";
  };
  services.forgejo = {
    enable = true;
    # TODO db backups
    # dump.enable = true;
    user = "git";
    group = "git";
    lfs.enable = true;
    secrets.mailer.PASSWD = config.age.secrets.mailer-password.path;
    settings = {
      DEFAULT.APP_NAME = "Czichy Git"; # tungsten inert gas?
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
      database = {
        SQLITE_JOURNAL_MODE = "WAL";
        LOG_SQL = false; # Leaks secrets
      };
      # federation.ENABLED = true;
      mailer = {
        ENABLED = true;
        SMTP_ADDR = "smtp.ionos.de";
        FROM = "nas@czichy.com";
        USER = "nas@czichy.com";
        SEND_AS_PLAIN_TEXT = true;
      };
      metrics = {
        # XXX: query with local telegraf
        ENABLED = true;
        ENABLED_ISSUE_BY_REPOSITORY = true;
        ENABLED_ISSUE_BY_LABEL = true;
      };
      oauth2_client = {
        # Never use auto account linking with this, otherwise users cannot change
        # their new user name and they could potentially overtake other users accounts
        # by setting their email address to an existing account.
        # With "login" linking the user must choose a non-existing username first or login
        # with the existing account to link.
        ACCOUNT_LINKING = "login";
        USERNAME = "nickname";
        # This does not mean that you cannot register via oauth, but just that there should
        # be a confirmation dialog shown to the user before the account is actually created.
        # This dialog allows changing user name and email address before creating the account.
        ENABLE_AUTO_REGISTRATION = false;
        REGISTER_EMAIL_CONFIRM = false;
        UPDATE_AVATAR = true;
      };
      repository = {
        DEFAULT_PRIVATE = "private";
        ENABLE_PUSH_CREATE_USER = true;
        ENABLE_PUSH_CREATE_ORG = true;
      };
      server = {
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
        DOMAIN = forgejoDomain;
        ROOT_URL = "https://${forgejoDomain}/";
        LANDING_PAGE = "login";
        SSH_PORT = 9922;
        SSH_USER = "git";
      };
      service = {
        DISABLE_REGISTRATION = true;
        ALLOW_ONLY_INTERNAL_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = false;
        SHOW_REGISTRATION_BUTTON = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_NOTIFY_MAIL = true;
      };
      session.COOKIE_SECURE = true;
      ui = {
        DEFAULT_THEME = "forgejo-dark";
        EXPLORE_PAGING_NUM = 5;
        SHOW_USER_EMAIL = false; # hide user email in the explore page
        GRAPH_MAX_COMMIT_NUM = 200;
      };

      "ui.meta" = {
        AUTHOR = "Czichy's Private Git Instance";
        DESCRIPTION = ''
          Czichy's private Git instance.
        '';
      };
      migrations.ALLOWED_DOMAINS = "github.com, *.github.com, gitlab.com, *.gitlab.com";
      packages.ENABLED = false;
      repository.PREFERRED_LICENSES = "MIT,GPL-3.0,GPL-2.0,LGPL-3.0,LGPL-2.1";
      # backup
      dump = {
        enable = true;
        backupDir = "/dump/forgejo/dump";
        interval = "01:00";
        type = "tar.zst";
      };
    };
  };

  # |----------------------------------------------------------------------| #
  # systemd.services.forgejo = {
  #   serviceConfig.RestartSec = "60"; # Retry every minute
  #   preStart = let
  #     exe = lib.getExe config.services.forgejo.package;
  #     providerName = "kanidm";
  #     clientId = "forgejo";
  #     args = lib.escapeShellArgs (lib.concatLists [
  #       ["--name" providerName]
  #       ["--provider" "openidConnect"]
  #       ["--key" clientId]
  #       ["--auto-discover-url" "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}/.well-known/openid-configuration"]
  #       ["--scopes" "email"]
  #       ["--scopes" "profile"]
  #       ["--group-claim-name" "groups"]
  #       ["--admin-group" "admin"]
  #       ["--skip-local-2fa"]
  #     ]);
  #   in
  #     lib.mkAfter ''
  #       provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
  #       SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})"
  #       if [[ -z "$provider_id" ]]; then
  #         ${exe} admin auth add-oauth ${args} --secret "$SECRET"
  #       else
  #         ${exe} admin auth update-oauth --id "$provider_id" ${args} --secret "$SECRET"
  #       fi
  #     '';
  # };
  # |----------------------------------------------------------------------| #
  systemd.services.forgejo.preStart = let
    adminCmd = "${lib.getExe config.services.forgejo.package} admin user";
    admin-pwd = config.age.secrets.admin-password.path;
    admin = "user@admin"; # Note, Forgejo doesn't allow creation of an account named "admin"
    user-pwd = config.age.secrets.user-password.path;
    user = "czichy";
  in ''
    ${adminCmd} create --admin --email "root@localhost" --username ${admin} --password "$(tr -d '\n' < ${admin-pwd})" || true
    ${adminCmd} create --email "christian@czichy.com" --username ${user} --password "$(tr -d '\n' < ${user-pwd})" || true
    ## uncomment this line to change an admin user which was already created
    # ${adminCmd} change-password --username ${user} --password "$(tr -d '\n' < ${user-pwd})" || true
  '';

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = config.services.forgejo.stateDir;
        inherit (config.services.forgejo) user group;
        mode = "0700";
      }
    ];
  };
  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = config.services.forgejo.dump.backupDir;
      inherit (config.services.forgejo) user group;
      mode = "0700";
    }
  ];

  fileSystems = lib.mkMerge [
    {
      "/state".neededForBoot = true;
    }
  ];
  # |----------------------------------------------------------------------| #

  systemd.services.backup-forgejo.environment.DATA_FOLDER = lib.mkForce "${config.services.forgejo.dump.backupDir}";

  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    uptime-kuma_url = "https://uptime.czichy.com/api/push/GKSOjgPE8e?status=up&msg=OK&ping=";

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
    forgejo-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-forgejo";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = [config.services.forgejo.dump.backupDir];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-forgejo.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "forgejo" uptime-kuma_url;

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
  };

  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
