{
  config,
  globals,
  nodes,
  secretsPath,
  hostName,
  lib,
  pkgs,
  ...
}: let
  # |----------------------------------------------------------------------| #
  forgejoDomain = "git.czichy.com";
  # forgejoDomain = "git.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";

  # ---------------------------------------------------------------------------
  # Secret-Existenz-Prüfungen (Build schlägt nicht fehl wenn Secrets fehlen)
  # ---------------------------------------------------------------------------
  # Gleiches Secret wie in kanidm.nix (basicSecretFile für den OAuth2-Client "forgejo").
  # Kanidm und Forgejo müssen denselben client_secret kennen.
  oauth2SecretFile = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-forgejo.age";
  hasOAuth2Secret = builtins.pathExists oauth2SecretFile;
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
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/restic-forgejo.age";
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

  age.secrets.forgejo-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # OAuth2 Client-Secret für Kanidm SSO (nur wenn .age-Datei vorhanden)
  age.secrets.forgejo-oauth2-client-secret = lib.mkIf hasOAuth2Secret {
    file = oauth2SecretFile;
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };
  # |----------------------------------------------------------------------| #
  globals.services.forgejo = {
    domain = forgejoDomain;
    homepage = {
      enable = true;
      name = "Forgejo";
      icon = "sh-forgejo";
      description = "Lightweight self-hosted Git service with code review & CI/CD";
      category = "Development & Collaboration";
      priority = 5;
      abbr = "FJ";
    };
  };
  globals.monitoring.http.forgejo = {
    url = "https://${forgejoDomain}/user/login";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      config.services.forgejo.settings.server.HTTP_PORT
      config.services.forgejo.settings.server.SSH_PORT
    ];
  };
  # |----------------------------------------------------------------------| #

  # Der äußere Caddy (HL-4-PAZ-PROXY-01) muss die Verbindung zum inneren Caddy
  # über HTTPS aufbauen. Da es sich um eine interne Verbindung handelt und der
  # innere Caddy möglicherweise ein selbst-signiertes Zertifikat verwendet,
  # müssen Sie die Zertifikatsprüfung deaktivieren.
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${forgejoDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                # Da der innere Caddy ein eigenes Zertifikat ausstellt,
                # muss die Überprüfung auf dem äußeren Caddy übersprungen werden.
                # Dies ist ein Workaround, wenn die Zertifikatskette nicht vertrauenswürdig ist.
                # tls_insecure_skip_verify
                # tls_server_name stellt sicher, dass der Hostname für die TLS-Handshake übermittelt wird.
                tls_server_name ${forgejoDomain}
            }
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${forgejoDomain}".extraConfig = ''
        reverse_proxy http://10.15.40.14:${toString config.services.forgejo.settings.server.HTTP_PORT}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
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
      # Only allow system-level authorized_keys to avoid injections.
      # We currently don't enable this when git-based software that relies on this is enabled.
      # It would be nicer to make it more granular using `Match`.
      # However those match blocks cannot be put after other `extraConfig` lines
      # with the current sshd config module, which is however something the sshd
      # config parser mandates.
      "/etc/ssh/authorized_keys.d/%u" # remove after instial setup
      "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
    ];
    # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
    settings.AcceptEnv = ["GIT_PROTOCOL"];
  };
  services.forgejo = {
    enable = true;
    user = "git";
    group = "git";
    lfs.enable = true;
    secrets.mailer.PASSWD = config.age.secrets.mailer-password.path;
    settings = {
      DEFAULT.APP_NAME = "Czichy Git"; # tungsten inert gas?
      actions = {
        ENABLED = false;
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
        LANDING_PAGE = "/explore/repos";
        DISABLE_SSH = false;
        SSH_PORT = 9922;
        SSH_USER = "git";
        START_SSH_SERVER = true;
        SSH_DOMAIN = forgejoDomain;

        BUILTIN_SSH_SERVER_USER = "git";
        # SSH_LISTEN_PORT = 22;
        # SSH_LISTEN_HOST = "100.121.201.47";
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
  systemd.services.forgejo.serviceConfig.RestartSec = "60"; # Bei Fehler 60s warten

  systemd.services.forgejo.preStart = let
    adminCmd = "${lib.getExe config.services.forgejo.package} admin user";
    admin-pwd = config.age.secrets.admin-password.path;
    admin = "administrator"; # Note, Forgejo doesn't allow creation of an account named "admin"
    user-pwd = config.age.secrets.user-password.path;
    user = "czichy";

    # --- Kanidm OAuth2 Provider Registration ---
    exe = lib.getExe config.services.forgejo.package;
    providerName = "kanidm";
    clientId = "forgejo";
    oauthArgs = lib.escapeShellArgs (lib.concatLists [
      ["--name" providerName]
      ["--provider" "openidConnect"]
      ["--key" clientId]
      ["--auto-discover-url" "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}/.well-known/openid-configuration"]
      ["--scopes" "email"]
      ["--scopes" "profile"]
      ["--group-claim-name" "groups"]
      ["--admin-group" "admin"]
      ["--skip-local-2fa"]
    ]);
  in ''
    ${adminCmd} create --admin --email "root@localhost" --username ${admin} --password "$(tr -d '\n' < ${admin-pwd})" || true
    ${adminCmd} create --email "christian@czichy.com" --username ${user} --password "$(tr -d '\n' < ${user-pwd})" || true
    ## uncomment this line to change an admin user which was already created
    # ${adminCmd} change-password --username ${user} --password "$(tr -d '\n' < ${user-pwd})" || true

    # --- Kanidm OAuth2 Provider anlegen/aktualisieren ---
    if [[ -f "${config.age.secrets.forgejo-oauth2-client-secret.path}" ]]; then
      provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
      SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})"
      if [[ -z "$provider_id" ]]; then
        ${exe} admin auth add-oauth ${oauthArgs} --secret "$SECRET" || echo "Warning: failed to add OAuth2 provider"
      else
        ${exe} admin auth update-oauth --id "$provider_id" ${oauthArgs} --secret "$SECRET" || echo "Warning: failed to update OAuth2 provider"
      fi
    else
      echo "Warning: OAuth2 client secret not found at ${config.age.secrets.forgejo-oauth2-client-secret.path}, skipping Kanidm SSO setup"
    fi
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
    ntfy_url = "https://ntfy.czichy.com/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.forgejo-hc-ping.path})"
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
      backupCleanupCommand = script-post config.networking.hostName "forgejo";

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
  # system.stateVersion = "25.11";
}
