{
  config,
  secretsPath,
  hostName,
  lib,
  ...
}: let
  # |----------------------------------------------------------------------| #
  cfg = {
    user = "root";
    group = "root";
    dataDir = "/shared/shares";
    configDir = "/root/.config/syncthing";
    isServer = true;
  };
  # |----------------------------------------------------------------------| #
  users = {
    christian = {
      id = 1000;
      groups = ["czichys" "syncthing"];
    };
    # ina = {
    #   id = 1001;
    #   groups = ["czichys" "samba"];
    # };
  };
  groups = {czichys = {id = 1002;};};
  # |----------------------------------------------------------------------| #
  # devices = lib.attrsets.filterAttrs (h: _: h != hostName) {
  devices = {
    "HL-1-OZ-PC-01" = {
      id = "QBEVQY4-KBNMIBW-MTY7SEC-DNBDN7J-OL7HHJ7-K7S5EXD-MF3FAHZ-RRFBHAR";
      # This option would be nice but we can't use it because there's no way to
      # declaratively configure shared folders we recieve. This just auto
      # accepts the folders with some default settings. Also, it forces shared
      # folders to have 700 permission mask which makes accessing shared files
      # from our own user impossible.
      autoAcceptFolders = false;
      # allowedNetwork = "192.168.0.0/16";
      # addresses = [ "tcp://192.168.0.99:51820" ];
    };

    "HL-3-RZ-SYNC-01" = {
      id = "UFTAS4W-V5CJBPI-CRH2T4I-47SX34E-7OQKHH5-RXD5SAN-NAZ2ADX-W7TNPAK";
    };
  };
  # |----------------------------------------------------------------------| #
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
  # |----------------------------------------------------------------------| #
in {
  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  age.secrets = {
    syncthingCert = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/syncthing/cert.pem.age";
      # refer to ./xxx.age located in `mysecrets` repo
      mode = "0600";
      owner = "${cfg.user}";
    };
    syncthingKey = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/syncthing/key.pem.age";
      # refer to ./xxx.age located in `mysecrets` repo
      mode = "0600";
      owner = "${cfg.user}";
    };
  };
  # |----------------------------------------------------------------------| #

  networking.firewall = {
    allowedTCPPorts = [
      8384 # Port for Syncthing.
    ];
  };
  systemd.tmpfiles.rules = [
    "d ${cfg.configDir} - root root"
    "d /${cfg.user}/.config - root root"
  ];
  services.syncthing = {
    enable = true;
    configDir = "${cfg.configDir}";
    user = "${cfg.user}";
    group = "${cfg.group}";

    dataDir = "${cfg.dataDir}";

    cert = config.age.secrets.syncthingCert.path;
    key = config.age.secrets.syncthingKey.path;

    guiAddress = "127.0.0.1:8384";

    settings = {
      # Disable this on non-servers as the folder has to be manually added
      # overrides any devices added or deleted through the WebUI
      overrideDevices = !cfg.isServer;

      # overrides any folders added or deleted through the WebUI
      overrideFolders = true;

      inherit devices;
      folders = {
        "iykxy-ruk4y" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/dokumente"; # Which folder to add to Syncthing
          devices = ["HL-1-OZ-PC-01" "HL-3-RZ-SYNC-01"]; # Which devices to share the folder with
        };
        "lhqxb-zc6qj" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/users/christian/Trading"; # Which folder to add to Syncthing
          devices = ["HL-1-OZ-PC-01" "HL-3-RZ-SYNC-01"]; # Which devices to share the folder with
        };
        "nandi-sj5en" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/users/christian/.credentials"; # Which folder to add to Syncthing
          devices = ["HL-1-OZ-PC-01" "HL-3-RZ-SYNC-01"]; # Which devices to share the folder with
        };
      };
      options.globalAnnounceEnabled = false; # Only sync on LAN
      gui.insecureSkipHostcheck = true;
      gui.insecureAdminAccess = true;
    };
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
    # ++ [
    #   (mkPersistent "/shared" "/shares/users/christian/Trading" "christian" "christian")
    #   (mkPersistent "/shared" "/shares/users/christian/.credentials" "christian" "christian")
    #   (mkPersistent "/shared" "/sync/dokumente" "christian" "czichys")
    # ]
  );
  # |----------------------------------------------------------------------| #

  fileSystems = lib.mkMerge [
    {
      "/shared".neededForBoot = true;
    }
  ];

  # |----------------------------------------------------------------------| #
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
        // lib.mapAttrs (name: cfg: mkUser name cfg.id cfg.groups) users
        // lib.mapAttrs (name: cfg: mkUser name cfg.id []) groups
      )
    ];

  users.groups = lib.mapAttrs (_: cfg: {gid = cfg.id;}) (users // groups);

  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
