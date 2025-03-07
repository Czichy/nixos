{
  localFlake,
  secretsPath,
}: {
  config,
  lib,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkAgenixEnableOption
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.services.resilio;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.services.resilio = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the networkmanager service.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.resilio = {
        enable = true;
        enableWebUI = false;
        checkForUpdates = false;
        downloadLimit = 0;
        uploadLimit = 0;
        deviceName = hostName;
        listeningPort = 4444;
      };
    }
    # |----------------------------------------------------------------------| #
    # {
    #   services.resilio.sharedFolders = [
    #     {
    #       secret = "the key"; # I want to make a mirror on the server, so the read-only key works perfectly
    #       directory = ;
    #       knownHosts = [];
    #       useRelayServer = true;
    #       useTracker = true;
    #       useDHT = true;
    #       searchLAN = true;
    #       useSyncTrash = true;
    #     }
    #   ];
    # }
    # |----------------------------------------------------------------------| #
    # Network
    {
      networking = {
        firewall.allowedTCPPorts = [4444]; # let connect directly to Resilio Sync
      };
    }
    # |----------------------------------------------------------------------| #
    # (mkIf agenixCheck {
    #   age.secrets = {
    #     syncthingCert = {
    #       symlink = true;
    #       file = secretsPath + "/hosts/HL-1-OZ-PC-01/users/${cfg.user}/syncthing/cert.pem.age";
    #       # refer to ./xxx.age located in `mysecrets` repo
    #       mode = "0600";
    #       owner = "${cfg.user}";
    #     };
    #     syncthingKey = {
    #       symlink = true;
    #       file = secretsPath + "/hosts/HL-1-OZ-PC-01/users/${cfg.user}/syncthing/key.pem.age";
    #       # refer to ./xxx.age located in `mysecrets` repo
    #       mode = "0600";
    #       owner = "${cfg.user}";
    #     };
    #   };
    # })
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [config.services.resilio.storagePath];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
