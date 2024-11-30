{
  config,
  globals,
  secretsPath,
  lib,
  pkgs,
  ...
}: let
  sambaDomain = "smb.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
  # smbUsers = config.repo.secrets.local.samba.users;
  smbUsers = {
    christian = {
      id = 1000;
      groups = ["czichys" "samba"];
    };
    ina = {
      id = 1001;
      groups = ["czichys" "samba"];
    };
    brother = {
      id = 1003;
      groups = ["samba"];
    };
  };
  # smbGroups = config.repo.secrets.local.samba.groups;
  smbGroups = {czichys = {id = 1002;};};
  mkPersistent = persistRoot: directory: owner: group: {
    ${persistRoot}.directories = [
      {
        inherit directory;
        user = owner;
        group = group;
        mode = "0750";
      }
    ];
  };
  mkCustomShare = {
    name,
    path,
    user ? "smb",
    group ? "smb",
    validUser ? "smb",
    hasBunker ? false,
    hasPaperless ? false,
    persistRoot ? "/panzer",
  }: cfg: let
    config =
      {
        "read only" = "no";
        "writeable" = "yes";
        "guest ok" = "no";
        "create mask" = "0740";
        "directory mask" = "0750";
        # "force user" = user;
        "force group" = group;
        "valid users" = "${validUser}";
        "write list" = "${validUser}";
        # "force create mode" = "0660";
        # "force directory mode" = "0770";
        # Might be necessary for windows user to be able to open thing in smb
        "acl allow execute always" = "no";
      }
      // cfg;
  in
    {
      "${name}" =
        config
        // {
          "path" = "${path}";
        };
    }
    // lib.optionalAttrs hasBunker {
      "${name}-important" =
        config
        // {
          "path" = "${path}-important";
          "#persistRoot" = "/bunker";
        };
    }
    // lib.optionalAttrs hasPaperless {
      "${name}-paperless" =
        config
        // {
          "path" = "/media/smb/${name}-paperless";
          "#paperless" = true;
          "force user" = "paperless";
          "force group" = "paperless";
          # Empty to prevent imperamence setting a persistence folder
          "#persistRoot" = "";
        };
    };

  mkShare = id: path: cfg: {
    ${id} =
      {
        inherit path;
        public = "no";
        writable = "yes";
        "create mask" = "0740";
        "directory mask" = "0750";
        "acl allow execute always" = "yes";
      }
      // cfg;
  };

  mkGroupShares = group: {enableBunker ? false, ...}:
    [
      (mkShare group "/shares/groups/${group}" {
        "valid users" = "@${group}";
        "force user" = group;
        "force group" = group;
      })
    ]
    ++ lib.optional enableBunker (
      mkShare "${group}-bunker" "/shares/groups/${group}-bunker" {
        "valid users" = "@${group}";
        "force user" = group;
        "force group" = group;
      }
    );

  mkUserShares = user: {
    enableBunker ? false,
    enablePaperless ? false,
    ...
  }:
    [
      (mkShare user "/shares/users/${user}" {
        "valid users" = user;
      })
    ]
    ++ lib.optional enableBunker (
      mkShare "${user}-bunker" "/shares/users/${user}-bunker" {
        "valid users" = user;
      }
    )
    ++ lib.optional enablePaperless (
      mkShare "${user}-paperless" "/shares/users/${user}-paperless" {
        "valid users" = user;
        "force user" = "paperless";
        "force group" = "paperless";
      }
    );
in {
  networking.hostName = "HL-3-RZ-SMB-01";

  # |----------------------------------------------------------------------| #
  # Use user and group information from TDB database.
  # The age-encrypted database is created by setting in the config
  # > "passdb backend" = "tdbsam:/tmp/samba-password-database";
  # and running
  # > sudo pdbedit --create --user=caspervk
  # then export the database using 'pdbedit -e tdbsam:<location>'
  age.secrets."samba-passdb.tdb" = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/samba/passdb.tdb.age";
    mode = "600";
  };
  # |----------------------------------------------------------------------| #
  environment.persistence = lib.mkMerge (
    [
      {
        "/persist".files = [
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      }
    ]
    ++ lib.flatten (
      lib.flip lib.mapAttrsToList smbUsers (
        name: {enableBunker ? false, ...}:
          [(mkPersistent "/shared" "/shares/users/${name}" name name)]
          ++ lib.optional enableBunker (
            mkPersistent "/bunker" "/shares/users/${name}-bunker" name name
          )
      )
      ++ lib.flip lib.mapAttrsToList smbGroups (
        name: {enableBunker ? false, ...}:
          [(mkPersistent "/shared" "/shares/groups/${name}" name name)]
          ++ lib.optional enableBunker (
            mkPersistent "/bunker" "/shares/groups/${name}-bunker" name name
          )
      )
      ++ [
        # (mkPersistent "/storage" "/shares/bibliothek" "christian" "czichys")
        # (mkPersistent "/storage" "/shares/dokumente" "christian" "czichys")
        # (mkPersistent "/storage" "/shares/media" "christian" "czichys")
        # (mkPersistent "/storage" "/shares/schule" "ina" "ina")
        #
        (mkPersistent "/shared" "/shares/bibliothek" "christian" "czichys")
        (mkPersistent "/shared" "/shares/dokumente" "christian" "czichys")
        (mkPersistent "/shared" "/shares/media" "christian" "czichys")
        (mkPersistent "/shared" "/shares/schule" "ina" "ina")
      ]
    )
  );

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # |----------------------------------------------------------------------| #
  globals.services.samba.domain = sambaDomain;
  globals.monitoring.tcp.samba = {
    host = globals.net.vlan40.hosts.HL-3-RZ-SMB-01.id;
    port = 445;
    network = "servers";
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${sambaDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."${config.networking.hostName}".ipv4}:445
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # The setup can be tested by:
  # > smbclient -L \\\\192.168.0.10
  # > smbclient \\\\192.168.0.21\\downloads -U caspervk

  services.samba = {
    enable = true;
    openFirewall = true;
    # `samba4Full` is compiled with avahi, ldap, AD etc support (compared to the default package, `samba`
    # Required for samba to register mDNS records for auto discovery
    # See https://github.com/NixOS/nixpkgs/blob/592047fc9e4f7b74a4dc85d1b9f5243dfe4899e3/pkgs/top-level/all-packages.nix#L27268
    package = pkgs.samba4Full;
    # Disable Samba's nmbd, because we don't want to reply to NetBIOS over IP
    # requests, since all of our clients hardcode the server shares.
    nmbd.enable = false;
    # Disable Samba's winbindd, which provides a number of services to the Name
    # Service Switch capability found in most modern C libraries, to arbitrary
    # applications via PAM and ntlm_auth and to Samba itself.
    winbindd.enable = false;
    settings = lib.mkMerge (
      [
        {
          global = {
            # Show the server host name in the printer comment box in print manager
            # and next to the IPC connection in net view.
            "server string" = "SambaCzichy";
            # Set the NetBIOS name by which the Samba server is known.
            "netbios name" = "SambaCzichy";
            # Disable netbios support. We don't need to support browsing since all
            # clients hardcode the host and share names.
            "disable netbios" = "yes";
            # Deny access to all hosts by default.
            "hosts deny" = "0.0.0.0/0";
            # Allow access to local network and TODO: wireguard
            "hosts allow" = "${globals.net.vlan40.cidrv4} ${globals.net.vlan10.cidrv4} ";
            # Don't advertise inaccessible shares to users
            "access based share enum" = "yes";

            # Set sane logging options
            "log level" = "0 auth:2 passdb:2";
            "log file" = "/dev/null";
            "max log size" = "1024";
            "logging" = "systemd";

            # Users always have to login with an account and are never mapped
            # to a guest account.
            # "passdb backend" = "tdbsam:/tmp/samba-password-database";
            "passdb backend" = "tdbsam:${config.age.secrets."samba-passdb.tdb".path}";
            "server role" = "standalone";
            "guest account" = "nobody";
            "map to guest" = "never";

            # Clients should only connect using the latest SMB3 protocol (e.g., on
            # clients running Windows 8 and later).
            # "server min protocol" = "SMB3_11";
            # Require native SMB transport encryption by default.
            "server smb encrypt" = "required";

            # Never map anything to the excutable bit.
            "map archive" = "no";
            "map system" = "no";
            "map hidden" = "no";

            # Disable printer sharing. By default Samba shares printers configured
            # using CUPS.
            "load printers" = "no";
            "printing" = "bsd";
            "printcap name" = "/dev/null";
            "disable spoolss" = "yes";
            "show add printer wizard" = "no";

            # Load in modules (order is critical!) and enable AAPL extensions.
            "vfs objects" = "catia fruit streams_xattr";
            # Enable Apple's SMB2+ extension.
            "fruit:aapl" = "yes";
            # Clean up unused or empty files created by the OS or Samba.
            "fruit:wipe_intentionally_left_blank_rfork" = "yes";
            "fruit:delete_empty_adfiles" = "yes";

            # "client min protocol" = "SMB2";
            # "client max protocol" = "SMB3";
          };
        }
        (mkCustomShare {
          name = "media";
          path = "/shares/media";
          user = "christian";
          validUser = "christian,ina";
          group = "czichys";
          hasBunker = false;
        } {})

        (mkCustomShare {
          name = "dokumente";
          path = "/shares/dokumente";
          user = "christian";
          validUser = "christian,ina";
          group = "czichys";
          hasBunker = false;
        } {})

        (mkCustomShare {
          name = "scanned_documents";
          path = "/shares/dokumente/scanned_documents";
          user = "brother";
          validUser = "christian,ina,brother";
          group = "czichys";
          hasBunker = false;
        } {})

        (mkCustomShare {
          name = "bibliothek";
          path = "/shares/bibliothek";
          user = "christian";
          validUser = "christian,ina";
          group = "czichys";
          hasBunker = false;
        } {})
      ]
      ++ lib.flatten (
        lib.mapAttrsToList mkUserShares smbUsers
        # ++ lib.mapAttrsToList mkGroupShares smbGroups
      )
    );
  };

  # tmpfiles to create shares if not yet present
  systemd.tmpfiles.settings = {
    "10-samba-shares" = {
      "/shares/bibliothek".d = {
        user = "christian";
        group = "czichys";
        mode = "0660";
      };
      "/shares/media".d = {
        user = "christian";
        group = "czichys";
        mode = "0660";
      };
      "/shares/dokumente".d = {
        user = "christian";
        group = "czichys";
        mode = "0660";
      };
      "/shares/dokumente/scanned_documents".d = {
        user = "brother";
        group = "czichys";
        mode = "0660";
      };
    };
  };
  fileSystems = lib.mkMerge [
    {
      "/storage".neededForBoot = true;
      "/shared".neededForBoot = true;
      "/bunker".neededForBoot = true;
    }
  ];

  users.users = let
    mkUser = name: id: groups: {
      isNormalUser = true;
      uid = id;
      group = name;
      extraGroups = groups;
      createHome = false;
      home = "/var/empty";
      useDefaultShell = false;
      autoSubUidGidRange = false;
    };
  in
    lib.mkMerge [
      (
        {}
        // lib.mapAttrs (name: cfg: mkUser name cfg.id cfg.groups) smbUsers
        // lib.mapAttrs (name: cfg: mkUser name cfg.id []) smbGroups
      )
    ];

  users.groups =
    {
      paperless.gid = config.ids.gids.paperless;
    }
    // lib.mapAttrs (_: cfg: {gid = cfg.id;}) (smbUsers // smbGroups);

  # |----------------------------------------------------------------------| #
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };
  age.secrets.restic-bibliothek = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/library.age";
    mode = "440";
  };
  age.secrets.restic-dokumente = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/dokumente.age";
    mode = "440";
  };
  age.secrets.restic-media = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/media.age";
    mode = "440";
  };
  age.secrets.restic-christian = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/christian.age";
    mode = "440";
  };
  age.secrets.restic-ina = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/restic/ina.age";
    mode = "440";
  };
  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };
  age.secrets.samba-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    pingKey = "$(cat ${config.age.secrets.samba-hc-ping.path})";
    slug = "https://health.czichy.com/ping/${pingKey}";

    script-post = host: site: ''
      if [ $EXIT_STATUS -ne 0 ]; then
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
        -H 'Title: Backup (${site}) on ${host} failed!' \
        -H 'Tags: backup,restic,${host},${site}' \
        -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/backup-${site}/fail"
      else
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
        -H 'Title: Backup (${site}) on ${host} successful!' \
        -H 'Tags: backup,restic,${host},${site}' \
        -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}/backup-${site}"
      fi
    '';
  in {
    dokumente-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-dokumente";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["shares/dokumente"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-dokumente.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "dokumente";

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
        OnCalendar = "*-*-* 00:30:00";
      };
    };
    bibliothek-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-bibliothek";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["shares/bibliothek"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-bibliothek.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "bibliothek";

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
        OnCalendar = "*-*-* 00:45:00";
      };
    };
    media-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-media";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["shares/media"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-media.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "media";

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
        OnCalendar = "*-*-* 01:15:00";
      };
    };
    christian-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-christian";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["/shares/users/christian"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-christian.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "christian";

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
    ina-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-ina";

      # Which local paths to backup, in addition to ones specified via `dynamicFilesFrom`.
      paths = ["/shares/users/ina"];

      # Patterns to exclude when backing up. See
      #   https://restic.readthedocs.io/en/latest/040_backup.html#excluding-files
      # for details on syntax.
      exclude = [];

      passwordFile = config.age.secrets.restic-ina.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "ina";

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
        OnCalendar = "*-*-* 01:45:00";
      };
    };
  };
  # |----------------------------------------------------------------------| #
}
