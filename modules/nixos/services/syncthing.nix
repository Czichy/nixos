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
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkAgenixEnableOption;

  cfg = config.tensorfiles.services.syncthing;

  # impermanenceCheck =
  #   (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  # impermanence =
  #   if impermanenceCheck
  #   then config.tensorfiles.system.impermanence
  #   else {};
  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;

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
      id = "MJ7QFHU-TIMOUSL-6NNC55J-ADQ64CZ-DJOWJU3-HHQLCOQ-5WUXVXS-WHLCAQB";
    };
  };
in {
  options.tensorfiles.services.syncthing = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the networkmanager service.
    '';

    dataDir = mkOption {
      type = types.path;
      default = "/home/${cfg.user}";
      example = "/home/yourUser";
      description = ''
        The path where synchronised directories will exist.
      '';
    };
    configDir = mkOption {
      type = types.path;
      default = "/home/${cfg.user}/.config/syncthing";
      example = "/home/yourUser";
      description = ''
        The directory containing the database and logs.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "czichy"; # defaultUser;
      example = "yourUser";
      description = ''
        The user to run Syncthing as.
        By default, a user named `${defaultUser}` will be created whose home
        directory is [dataDir](#opt-services.syncthing.dataDir).
      '';
    };

    isServer = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether the host is Server
      '';
    };
    # impermanence = {
    #   enable = mkImpermanenceEnableOption;
    # };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    # --- Deployment Instructions ---
    # 1. For a new device, generate cert and key with `syncthing generate` then
    # add to agenix.
    # 2. Open http://localhost:8384 and add shared folders with staggered version
    # and ignore permissions enabled.

    # If the device is a server, syncthing files will not be accessible from the
    # main user account.
    # If the device is not a server, we apply a bunch of permission rules to
    # ensure that files and directories created in shared folders belong to group
    # 'syncthing' and have a 777 group permission mask. That way our main user
    # can create files in shared folders and syncthing will be able to access
    # them.

    # WARN: Downside of this setup is that if I move files or folders into a
    # synced dir, their group will not automatically be updated and syncthing
    # will not track them. Can be worked around with some sort of scheduled
    # systemd task that updates permissions.

    # NOTE: Something is broken, preventing the old config being merged with the
    # new one even though I have overrideFolders set to false
    # |----------------------------------------------------------------------| #

    {
      # Add main user to the syncthing group
      users.users.${cfg.user}.extraGroups = mkIf (!cfg.isServer) ["syncthing"];
      systemd.tmpfiles.rules = [
        "d ${cfg.configDir} - czichy users"
        "d /home/${cfg.user}/.config - czichy users"
      ];
      # systemd.services.syncthing-init = {
      #   after = [ "${mountServiceName}" ];
      #   requires = [ "${mountServiceName}" ];
      #   serviceConfig = {
      #     # For the config init service to sleep to make sure the main service has
      #     # time to start
      #     # This didn't fix the issue but I got a 404 page not found error instead of localhost error
      #     # ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      #   };
      # };

      # systemd.services.syncthing = {
      #   after = [ "${mountServiceName}" ];
      #   requires = [ "${mountServiceName}" ];
      #   serviceConfig = {
      #     # For the config init service to sleep to make sure the main service has
      #     # time to start
      #     # This didn't fix the issue but I got a 404 page not found error instead of localhost error
      #     # ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      #   };
      # };
      # systemd.services.syncthing = {
      #   bindsTo = ["home-czichy-.config-syncthing.mount"];
      #   after = ["home-czichy-.config-syncthing.mount"];
      # };

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
              devices = ["nas"]; # Which devices to share the folder with
            };
            "lhqxb-zc6qj" = {
              # Name of folder in Syncthing, also the folder ID
              path = "${cfg.dataDir}/Trading"; # Which folder to add to Syncthing
              devices = ["nas"]; # Which devices to share the folder with
            };
            "nandi-sj5en" = {
              # Name of folder in Syncthing, also the folder ID
              path = "${cfg.dataDir}/.credentials"; # Which folder to add to Syncthing
              devices = ["nas"]; # Which devices to share the folder with
            };
          };
          options.globalAnnounceEnabled = false; # Only sync on LAN
          gui.insecureSkipHostcheck = true;
          gui.insecureAdminAccess = true;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets = {
        syncthingCert = {
          symlink = true;
          # path = "/home/${cfg.user}/.config/syncthing/cert.pem";
          file = secretsPath + "/hosts/desktop/users/${cfg.user}/syncthing/cert.pem.age";
          # refer to ./xxx.age located in `mysecrets` repo
          mode = "0600";
          owner = "${cfg.user}";
        };
        syncthingKey = {
          symlink = true;
          # path = "/home/${cfg.user}/.config/syncthing/key.pem";
          file = secretsPath + "/hosts/desktop/users/${cfg.user}/syncthing/key.pem.age";
          # refer to ./xxx.age located in `mysecrets` repo
          mode = "0600";
          owner = "${cfg.user}";
        };
      };
    })
    # |----------------------------------------------------------------------| #
    # (mkIf impermanenceCheck {
    # environment.persistence."${impermanence.persistentRoot}".users.${cfg.user} = {
    #   directories = [
    #     {
    #       directory = "/.config/syncthing";
    #       # directory = pathToRelative cfg.configDir;
    #       user = "${cfg.user}";
    #       group = "users";
    #       mode = "u=rwx,g=rwx,o=";
    #     }

    #     # "/.config/syncthing"
    #   ];
    # };
    # })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
