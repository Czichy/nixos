{
  config,
  secretsPath,
  hostName,
  lib,
  pkgs,
  ...
}: let
  # |----------------------------------------------------------------------| #
  cfg = {
    user = "ina";
    group = "czichys";
    dataDir = "/shared/shares";
    configDir = "/home/ina/.config/syncthing";
    isServer = true;
  };
  # |----------------------------------------------------------------------| #
  users = {
    ina = {
      id = 1000;
      groups = ["czichys" "syncthing"];
    };
  };
  groups = {czichys = {id = 1002;};};
  # |----------------------------------------------------------------------| #
  # devices = lib.attrsets.filterAttrs (h: _: h != hostName) {
  devices = {
    "Inas-Yoga" = {
      id = "QBEVQY4-KBNMIBW-MTY7SEC-DNBDN7J-OL7HHJ7-K7S5EXD-MF3FAHZ-RRFBHAR";
      # This option would be nice but we can't use it because there's no way to
      # declaratively configure shared folders we recieve. This just auto
      # accepts the folders with some default settings. Also, it forces shared
      # folders to have 700 permission mask which makes accessing shared files
      # from our own user impossible.
      autoAcceptFolders = false;
    };

    "HL-3-RZ-SYNC-02" = {
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
  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/schule";
      # In the MicroVM
      mountPoint = "${cfg.dataDir}/schule";
      tag = "sync-schule";
      proto = "virtiofs";
    }
  ];
  # |----------------------------------------------------------------------| #
  age.secrets = {
    syncthingCert = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/sync_ina/cert.pem.age";
      mode = "0600";
      owner = "${cfg.user}";
    };
    syncthingKey = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/sync_ina/key.pem.age";
      mode = "0600";
      owner = "${cfg.user}";
    };
  };
  # |----------------------------------------------------------------------| #

  networking.firewall = {
    allowedTCPPorts = [
      8384 # Port for Syncthing Web UI.
      22000 # TCP based sync protocol traffic
    ];
    allowedUDPPorts = [
      22000 # QUIC based sync protocol traffic
      21027 # for discovery broadcasts on IPv4 and multicasts on IPv6
    ];
  };
  systemd.tmpfiles.rules = [
    "d ${cfg.configDir} - ina ina"
    "d /${cfg.user}/.config - ina ina"
    "d /${cfg.dataDir}/dokumente 2770 - ina syncthing"
  ];

  services.syncthing = {
    enable = true;
    configDir = "${cfg.configDir}";
    user = "${cfg.user}";
    group = "${cfg.group}";

    dataDir = "${cfg.dataDir}";
    cert = config.age.secrets.syncthingCert.path;
    key = config.age.secrets.syncthingKey.path;
    # To be able to access the web GUI from other computers, you need to change the
    # GUI Listen Address setting from the default 127.0.0.1:8384 to 0.0.0.0:8384.
    # You also need to open the port in your local firewall if you have one.
    guiAddress = "0.0.0.0:8384";
    settings = {
      # Disable this on non-servers as the folder has to be manually added
      # overrides any devices added or deleted through the WebUI
      overrideDevices = !cfg.isServer;

      # overrides any folders added or deleted through the WebUI
      overrideFolders = true;

      inherit devices;
      folders = {
        "lhqxb-zc6qj" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/schule"; # Which folder to add to Syncthing
          devices = ["Inas-YOGA" "HL-3-RZ-SYNC-02"]; # Which devices to share the folder with
        };
      };
      options.globalAnnounceEnabled = false; # Only sync on LAN
      gui.insecureSkipHostcheck = true;
      gui.insecureAdminAccess = true;
    };
  };
  systemd.services.syncthing.serviceConfig.UMask = "0007";
  # Don't create default ~/Sync folder
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  # |----------------------------------------------------------------------| #
  environment.persistence = lib.mkMerge [
    {
      "/persist".files = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    }
  ];
  # |----------------------------------------------------------------------| #

  # fileSystems = lib.mkMerge [
  #   {
  #     "/shared".neededForBoot = true;
  #   }
  # ];

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
