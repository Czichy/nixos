{
  config,
  globals,
  secretsPath,
  hostName,
  lib,
  pkgs,
  inputs,
  system,
  ...
}: let
  # |----------------------------------------------------------------------| #
  docspellDomain = "docs.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";

  full-text-search = {
    enabled = true;
    backend = "postgresql";
    postgresql = {
      use-default-connection = true;
      pg-config = {
        "german" = "my-german";
      };
    };
    # solr.url = "http://localhost:8983/solr/docspell";
  };
  jdbc = {
    # FIXME docspll does NOT support UNIX sockets!
    # url = "jdbc:postgresql://localhost:5432/docspell";
    url = "jdbc:postgresql://localhost:5432/docspell";
    user = "docspell";
    password = "docspell";
  };

  watchDir = "/shared/ina";
  header-value = "test123";
  # |----------------------------------------------------------------------| #
in {
  microvm.mem = 1024 * 6;
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

  # Add dsc to the environment
  # # Add dsc to the environment
  environment.systemPackages = [
    inputs.dsc.packages.${pkgs.system}.default
  ];
  imports = [
    inputs.docspell.nixosModules.default
    inputs.dsc.nixosModules.default
  ];
  # |----------------------------------------------------------------------| #
  age.secrets.server-secret = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/docspell/server-secret.age";
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };

  age.secrets.docspell-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  globals.services.docspell = {
    domain = docspellDomain;
    homepage = {
      enable = true;
      name = "Docspell";
      icon = "sh-docspell";
      description = "Personal document organizer with AI-powered tagging & full-text search";
      category = "Documents & Notes";
      priority = 10;
      abbr = "DS";
    };
  };
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

        # tls ${certloc}/fullchain.pem ${certloc}/key.pem {
        #   protocols tls1.3
        # }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${docspellDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-DOCSPL-01".ipv4}:${toString config.services.docspell-restserver.bind.port}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
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
  services.postgresql = let
    pginit = pkgs.writeText "pginit.sql" ''
      CREATE USER docspell WITH PASSWORD 'docspell' LOGIN CREATEDB;
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO docspell;
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO docspell;
      CREATE DATABASE DOCSPELL OWNER 'docspell';
    '';
  in {
    enable = true;
    initialScript = pginit;
    # package = pkgs.postgresql_15;
    # enableTCPIP = true;
    ensureDatabases = ["docspell"];
    ensureUsers = [
      {
        name = "docspell";
        # password = "docspell";
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };
  # |----------------------------------------------------------------------| #
  # https://docspell.org/docs/install/nix/

  # joex: job executor
  services.docspell-joex = {
    enable = true;
    app-id = "joexina";
    package = inputs.docspell.packages.${pkgs.system}.docspell-joex;
    base-url = "http://10.15.40.18:7878";
    bind = {
      address = "10.15.40.18";
      port = 7878;
    };
    scheduler = {
      pool-size = 1;
    };
    inherit jdbc;
  };
  # |----------------------------------------------------------------------| #
  services.docspell-restserver = {
    enable = true;
    package = inputs.docspell.packages.${pkgs.system}.docspell-restserver;
    app-id = "ina";
    base-url = "http://10.15.40.18:7880";
    bind = {
      address = "10.15.40.18";
      port = 7880;
    };
    integration-endpoint = {
      enabled = true;
      http-header = {
        enabled = true;
        inherit header-value;
      };
    };
    auth = {
      server-secret = "b64:bdUqcdpFgYl/MrkMlGnRDClUTKIU30CW0IMM/OSE6lk=";
    };
    backend = {
      addons.enabled = true;
      # Create invitation
      # curl -X POST -d '{"password":"dsinvite2"}' "http://localhost:7880/api/v1/open/signup/newinvite"
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
    # files {
    #   # Defines the chunk size (in bytes) used to store the files.
    #   # This will affect the memory footprint when uploading and
    #   # downloading files. At most this amount is loaded into RAM for
    #   # down- and uploading.
    #   #
    #   # It also defines the chunk size used for the blobs inside the
    #   # database.
    #   chunk-size = 524288

    #   # The file content types that are considered valid. Docspell
    #   # will only pass these files to processing. The processing code
    #   # itself has also checks for which files are supported and which
    #   # not. This affects the uploading part and can be used to
    #   # restrict file types that should be handed over to processing.
    #   # By default all files are allowed.
    #   valid-mime-types = [ ]

    #   # The id of an enabled store from the `stores` array that should
    #   # be used.
    #   #
    #   # IMPORTANT NOTE: All nodes must have the exact same file store
    #   # configuration!
    #   default-store = "database"

    #   # A list of possible file stores. Each entry must have a unique
    #   # id. The `type` is one of: default-database, filesystem, s3.
    #   #
    #   # The enabled property serves currently to define target stores
    #   # for te "copy files" task. All stores with enabled=false are
    #   # removed from the list. The `default-store` must be enabled.
    #   stores = {
    #     database =
    #       { enabled = true
    #         type = "default-database"
    #       }

    #     filesystem =
    #       { enabled = false
    #         type = "file-system"
    #         directory = "/some/directory"
    #       }

    #     minio =
    #      { enabled = false
    #        type = "s3"
    #        endpoint = "http://localhost:9000"
    #        access-key = "username"
    #        secret-key = "password"
    #        bucket = "docspell"
    #        region = ""
    #      }
    #   }
    # }
  };
  # |----------------------------------------------------------------------| #

  services.dsc-watch = let
    docspell-url = "http://10.15.40.18:7880";
  in {
    enable = true;
    package = inputs.dsc.packages.${pkgs.system}.default;
    inherit docspell-url;
    # docspell-url = "http://${globals.net.vlan40.hosts."HL-3-RZ-DOCSPL-01".ipv4}:${toString config.services.docspell-restserver.bind.port}";
    exclude-filter = null;
    watchDirs = [
      watchDir # Note, dsc expects files to be in a subdirectory corresponding to a collective. There is no way to declaratively create a collective as of the time of writing
    ];
    integration-endpoint = let
      headerFile = pkgs.writeText "int-header-file" ''
        Docspell-Integration:${header-value}
      '';
    in {
      enabled = true;
      header-file = headerFile;
    };
  };
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    # |----------------------------------------------------------------------| #
    # directories = [
    #   {
    #     directory = config.services.forgejo.stateDir;
    #     inherit (config.services.forgejo) user group;
    #     mode = "0700";
    #   }
    # ];
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
