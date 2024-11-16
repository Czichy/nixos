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
  age.secrets.vaultwarden-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-SBC-01/guests/vaultwarden/vaultwarden-env.age";
    mode = "440";
    group = "vaultwarden";
  };
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
    group = "vaultwarden";
  };
  age.secrets.restic-vaultwarden = {
    file = secretsPath + "/hosts/HL-1-MRZ-SBC-01/guests/vaultwarden/restic-vaultwarden.age";
    mode = "440";
    group = "vaultwarden";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "vaultwarden";
  };

  # |----------------------------------------------------------------------| #

  environment.persistence."/persist".directories = [
    {
      directory = config.services.forgejo.stateDir;
      inherit (config.services.forgejo) user group;
      mode = "0700";
    }
  ];

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
    allowedTCPPorts = [22 8012];
    allowedUDPPorts = [22 8012];
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
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-VAULT-01".ipv4}:${toString config.services.vaultwarden.config.rocketPort}
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
    secrets.mailer.PASSWD = config.age.secrets.forgejo-mailer-password.path;
    settings = {
      DEFAULT.APP_NAME = "Redlew Git"; # tungsten inert gas?
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
        SMTP_ADDR = config.repo.secrets.local.forgejo.mail.host;
        FROM = config.repo.secrets.local.forgejo.mail.from;
        USER = config.repo.secrets.local.forgejo.mail.user;
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
      # packages.ENABLED = true;
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
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_INTERNAL_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_NOTIFY_MAIL = true;
      };
      session.COOKIE_SECURE = true;
      ui.DEFAULT_THEME = "forgejo-auto";
      "ui.meta" = {
        AUTHOR = "Redlew Git";
        DESCRIPTION = "Tungsten Inert Gas?";
      };
    };
  };

  systemd.services.forgejo = {
    serviceConfig.RestartSec = "60"; # Retry every minute
    preStart = let
      exe = lib.getExe config.services.forgejo.package;
      providerName = "kanidm";
      clientId = "forgejo";
      args = lib.escapeShellArgs (lib.concatLists [
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
    in
      lib.mkAfter ''
        provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
        SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})"
        if [[ -z "$provider_id" ]]; then
          ${exe} admin auth add-oauth ${args} --secret "$SECRET"
        else
          ${exe} admin auth update-oauth --id "$provider_id" ${args} --secret "$SECRET"
        fi
      '';
  };
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
