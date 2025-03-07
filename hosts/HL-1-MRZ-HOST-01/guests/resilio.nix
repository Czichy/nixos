{
  config,
  secretsPath,
  hostName,
  globals,
  ...
}: let
  # |----------------------------------------------------------------------| #
  dataDir = "/shared/shares";
  # |----------------------------------------------------------------------| #
in {
  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/dokumente";
      # In the MicroVM
      mountPoint = "${config.services.resilio.storagePath}/dokumente";
      tag = "sync-dokumente";
      proto = "virtiofs";
    }
    {
      # On the host
      source = "/shared/shares/users/christian/Trading/";
      # In the MicroVM
      mountPoint = "${config.services.resilio.storagePath}/Trading";
      tag = "sync-trading";
      proto = "virtiofs";
    }
    {
      # On the host
      source = "/shared/shares/users/christian/.credentials/";
      # In the MicroVM
      mountPoint = "${dataDir}/users/christian/.credentials";
      tag = "sync-credentials";
      proto = "virtiofs";
    }
  ];
  # |----------------------------------------------------------------------| #
  age.secrets = {
    dokumente = {
      symlink = true;
      file = secretsPath + "/resilio/dokumente.age";
      mode = "0600";
    };
    trading = {
      symlink = true;
      file = secretsPath + "/resilio/trading.age";
      mode = "0600";
    };
  };
  # |----------------------------------------------------------------------| #

  networking.firewall = {
    allowedTCPPorts = [
      4444
    ];
  };
  # |----------------------------------------------------------------------| #
  services.resilio = {
    enable = true;
    enableWebUI = false;
    checkForUpdates = false;
    downloadLimit = 0;
    uploadLimit = 0;
    deviceName = hostName;
    listeningPort = 4444;
  };
  services.resilio.    
    sharedFolders = [
    {
      secretFile = config.age.secrets.trading.path; # I want to make a mirror on the server, so the read-only key works perfectly
      directory = "${config.services.resilio.storagePath}/trading";
      knownHosts = [globals.vlan10.hosts.HL-OZ-PC-01.id];
      useRelayServer = true;
      useTracker = true;
      useDHT = true;
      searchLAN = true;
      useSyncTrash = true;
    }
    {
      secretFile = config.age.secrets.dokumente.path; # I want to make a mirror on the server, so the read-only key works perfectly
      directory = "${config.services.resilio.storagePath}/dokumente";
      knownHosts = [globals.vlan10.hosts.HL-OZ-PC-01.id];
      useRelayServer = true;
      useTracker = true;
      useDHT = true;
      searchLAN = true;
      useSyncTrash = true;
    }
  ];
  # |----------------------------------------------------------------------| #
  users.users.rslsync.extraGroups = ["root"];
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [config.services.resilio.storagePath];
  };

  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
