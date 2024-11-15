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
    dataDir = "/shared";
    configDir = "/root/.config/syncthing";
    isServer = true;
  };
  # |----------------------------------------------------------------------| #
  devices = lib.attrsets.filterAttrs (h: _: h != hostName) {
    "desktop" = {
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
    "nas" = {
      id = "UFTAS4W-V5CJBPI-CRH2T4I-47SX34E-7OQKHH5-RXD5SAN-NAZ2ADX-W7TNPAK";
    };
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
    group = "users";

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
          path = "${cfg.dataDir}/Dokumente"; # Which folder to add to Syncthing
          devices = ["pc" "nas"]; # Which devices to share the folder with
        };
        "lhqxb-zc6qj" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/Trading"; # Which folder to add to Syncthing
          devices = ["pc" "nas"]; # Which devices to share the folder with
        };
        "nandi-sj5en" = {
          # Name of folder in Syncthing, also the folder ID
          path = "${cfg.dataDir}/.credentials"; # Which folder to add to Syncthing
          devices = ["pc" "nas"]; # Which devices to share the folder with
        };
      };
      options.globalAnnounceEnabled = false; # Only sync on LAN
      gui.insecureSkipHostcheck = true;
      gui.insecureAdminAccess = true;
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/unifi";
      mode = "0700";
    }
  ];

  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
