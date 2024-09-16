{
  # osConfig,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (config) modules;
  inherit (config.meta) hostname;

  sys = modules.system;
  srv = sys.services;
  cfg = srv.syncthing;

  agenixCheck = sys.agenix.enable;

  # TODO: config
  devices = lib.attrsets.filterAttrs (h: _: h != hostname) {
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
    "nas" = {
      id = "MJ7QFHU-TIMOUSL-6NNC55J-ADQ64CZ-DJOWJU3-HHQLCOQ-5WUXVXS-WHLCAQB";
    };
  };
in {
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
        "d ${cfg.configDir} - ${cfg.user} users"
        "d /home/${cfg.user}/.config - ${cfg.user} users"
      ];

      services.syncthing = {
        enable = true;
        configDir = "${cfg.configDir}";
        user = "${cfg.user}";
        group = "users";

        dataDir = "${cfg.dataDir}";

        cert = config.age.secrets.syncthingCert.path;
        key = config.age.secrets.syncthingKey.path;

        guiAddress = "127.0.0.1:${toString cfg.port}";

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
          file = sys.agenix.root.secretsPath + "/hosts/desktop/users/${cfg.user}/syncthing/cert.pem.age";
          # refer to ./xxx.age located in `mysecrets` repo
          mode = "0600";
          owner = "${cfg.user}";
        };
        syncthingKey = {
          symlink = true;
          # path = "/home/${cfg.user}/.config/syncthing/key.pem";
          file = sys.agenix.root.secretsPath + "/hosts/desktop/users/${cfg.user}/syncthing/key.pem.age";
          # refer to ./xxx.age located in `mysecrets` repo
          mode = "0600";
          owner = "${cfg.user}";
        };
      };
    })
    # |----------------------------------------------------------------------| #
  ]);
}
