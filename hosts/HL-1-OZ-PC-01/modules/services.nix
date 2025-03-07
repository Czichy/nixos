{
  config.tensorfiles.services = {
    flatpak.enable = true;
    networking.networkd.enable = true;
    printing.enable = true;
    # syncthing = {
    #   enable = true;
    #   user = "czichy";
    # };
    virtualisation.enable = true;
  };

  #   config.age.secrets = {
  #     dokumente = {
  #       symlink = true;
  #       file = secretsPath + "/resilio/dokumente.age";
  #       mode = "0600";
  #     };
  #     trading = {
  #       symlink = true;
  #       file = secretsPath + "/resilio/trading.age";
  #       mode = "0600";
  #     };
  #   };

  #   config.tensorfiles.services.resilio.enable = true;
  #   config.services.resilio = {
  #     deviceName = "HL-1-OZ-PC-01";
  #     sharedFolders = [
  #       {
  #         secret = config.age.secrets.syncthingCert.path; # I want to make a mirror on the server, so the read-only key works perfectly
  #         directory = config.home.sessionVariables.TRADING_DIR;
  #         knownHosts = [];
  #         useRelayServer = true;
  #         useTracker = true;
  #         useDHT = true;
  #         searchLAN = true;
  #         useSyncTrash = true;
  #       }
  #     ];
  #   };
}
