{
  config,
  globals,
  secretsPath,
  hostName,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # |----------------------------------------------------------------------| #
  docspellDomain = "git.${globals.domains.me}";

  certloc = "/var/lib/acme/czichy.com";

  full-text-search = {
    enabled = true;
    backend = "postgres";
    postgresql = {
      pg-config = {
        "german" = "my-germam";
      };
    };
    # solr.url = "http://localhost:8983/solr/docspell";
  };
  jdbc = {
    # FIXME docspll does NOT support UNIX sockets!
    # url = "jdbc:postgresql://localhost:5432/docspell";
    url = "jdbc:postgresql://localhost:5432/docspell";
    user = "docspell";
    password = "";
  };
  # |----------------------------------------------------------------------| #
in {
  microvm.mem = 1024 * 2;
  microvm.vcpu = 2;

  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/users/ina";
      # In the MicroVM
      mountPoint = "/shared/ina";
      tag = "ina";
      proto = "virtiofs";
    }
  ];

  networking.hostName = hostName;

  imports = [
    inputs.docspell.nixosModules.default
  ];
  # |----------------------------------------------------------------------| #
  age.secrets.mailer-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/mailer-password.age";
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

  age.secrets.docspell-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  globals.services.forgejo.domain = docspellDomain;
  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      config.services.docspell-restserver.bind.port
      config.services.docspell-joex.bind.port
    ];
  };
  # |----------------------------------------------------------------------| #

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${docspellDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${docspellDomain}
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
      virtualHosts."${docspellDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-DOCSPL-01".ipv4}:${toString config.services.forgejo.settings.server.HTTP_PORT}
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
    settings.AcceptEnv = "GIT_PROTOCOL";
  };
  # |----------------------------------------------------------------------| #
  # # install postgresql and initially create user/database
  # services.postgresql =
  # let
  #   pginit = pkgs.writeText "pginit.sql" ''
  #     CREATE USER docspell WITH PASSWORD 'docspell' LOGIN CREATEDB;
  #     GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO docspell;
  #     GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO docspell;
  #     CREATE DATABASE DOCSPELL OWNER 'docspell';
  #   '';
  # in {
  #     enable = true;
  #     package = pkgs.postgresql_11;
  #     enableTCPIP = true;
  #     initialScript = pginit;
  #     port = 5432;
  #     authentication = ''
  #       host  all  all 0.0.0.0/0 md5
  #     '';
  # };
  services.postgresql = {
    enable = true;
    # package = pkgs.postgresql_15;
    # enableTCPIP = true;
    ensureDatabases = ["docspell"];
    ensureUsers = [
      {
        name = "docspell";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };
  # |----------------------------------------------------------------------| #
  # services.solr = {
  #   enable = true;
  #   cores = ["docspell"];
  #   heap = 512;
  # };
  # # This is needed to run solr script as user solr
  # users.users.solr.useDefaultShell = true;
  # users.users.docspell.isSystemUser = pkgs.lib.mkForce true;

  # systemd.services.solr-init = let
  #   solrPort = toString config.services.solr.port;
  #   initSolr = ''
  #     if [ ! -f ${config.services.solr.stateDir}/docspell_core ]; then
  #       while ! echo "" | ${pkgs.inetutils}/bin/telnet localhost ${solrPort}
  #       do
  #          echo "Waiting for SOLR become ready..."
  #          sleep 1.5
  #       done
  #       ${pkgs.su}/bin/su -s ${pkgs.bash}/bin/sh solr -c "${pkgs.solr}/bin/solr create_core -c docspell -p ${solrPort}";
  #       touch ${config.services.solr.stateDir}/docspell_core
  #     fi
  #   '';
  # in {
  #   script = initSolr;
  #   after = ["solr.target"];
  #   wantedBy = ["multi-user.target"];
  #   requires = ["solr.target"];
  #   description = "Create a core at solr";
  # };
  # |----------------------------------------------------------------------| #
  # https://docspell.org/docs/install/nix/

  # joex: job executor
  services.docspell-joex = {
    enable = true;
    package = inputs.docspell.packages.${pkgs.system}.docspell-joex;
    base-url = "http://localhost:7878";
    bind = {
      address = "127.0.0.1";
      port = 7878;
    };
    scheduler = {
      pool-size = 1;
    };
    jdbc = {
      # FIXME docspll does NOT support UNIX sockets!
      # url = "jdbc:postgresql://localhost:5432/docspell";
      url = "jdbc:postgresql://%2Fvar%2Frun%2Fpostgresql/docspell";
      user = "docspell";
      password = "";
    };
  };
  # |----------------------------------------------------------------------| #
  services.docspell-restserver = {
    enable = true;
    package = inputs.docspell.packages.${pkgs.system}.docspell-restserver;
    base-url = "http://localhost:7880";
    bind = {
      address = "127.0.0.1";
      port = 7880;
    };
    integration-endpoint = {
      enabled = true;
      http-header = {
        enabled = true;
        header-value = "test123";
      };
    };
    auth = {
      server-secret = "b64:EirgaudMyNvWg4TvxVGxTu-fgtrto4ETz--Hk9Pv2o4=";
    };
    backend = {
      addons.enabled = true;
      signup = {
        mode = "invite";
        new-invite-password = "dsinvite2";
        invite-time = "30 days";
      };
      inherit jdbc;
    };
    admin-endpoint = {
      secret = "admin123";
    };
    inherit full-text-search;
  };
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
  # environment.persistence."/state".directories = [
  #   {
  #     directory = config.services.forgejo.dump.backupDir;
  #     inherit (config.services.forgejo) user group;
  #     mode = "0700";
  #   }
  # ];

  fileSystems = lib.mkMerge [
    {
      "/state".neededForBoot = true;
    }
  ];
  # |----------------------------------------------------------------------| #

  # systemd.services.backup-forgejo.environment.DATA_FOLDER = lib.mkForce "${config.services.forgejo.dump.backupDir}";

  # # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  # services.restic.backups = let
  #   ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
  #   ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
  #   slug = "https://health.czichy.com/ping/";

  #   script-post = host: site: ''
  #     pingKey="$(cat ${config.age.secrets.forgejo-hc-ping.path})"
  #     if [ $EXIT_STATUS -ne 0 ]; then
  #       ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
  #       -H 'Title: Backup (${site}) on ${host} failed!' \
  #       -H 'Tags: backup,restic,${host},${site}' \
  #       -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
  #       ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}/fail"
  #     else
  #       ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}"
  #     fi
  #   '';
  # in {
  #   forgejo-backup = {
  #     # Initialize the repository if it doesn't exist.
  #     initialize = true;

  #     # backup to a rclone remote
  #     repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-forgejo";

  #     # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
  #     paths = [config.services.forgejo.dump.backupDir];

  #     # Patterns to exclude when backing up. See
  #     #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
  #     # for details on syntax.
  #     exclude = [];

  #     passwordFile = config.age.secrets.restic-forgejo.path;
  #     rcloneConfigFile = config.age.secrets."rclone.conf".path;

  #     # A script that must run after finishing the backup process.
  #     backupCleanupCommand = script-post config.networking.hostName "forgejo";

  #     # A list of options (--keep-* et al.) for 'restic forget --prune',
  #     # to automatically prune old snapshots.
  #     # The 'forget' command is run *after* the 'backup' command, so
  #     # keep that in mind when constructing the --keep-* options.
  #     pruneOpts = [
  #       "--keep-daily 3"
  #       "--keep-weekly 3"
  #       "--keep-monthly 3"
  #       "--keep-yearly 3"
  #     ];

  #     # When to run the backup. See {manpage}`systemd.timer(5)` for details.
  #     timerConfig = {
  #       OnCalendar = "*-*-* 02:30:00";
  #     };
  #   };
  # };

  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
