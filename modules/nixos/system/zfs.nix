{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # authorizedkeys = [
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF1TFwXbqdC1UyG75q3HO1n7/L3yxpeRLIq2kQ9DalI"
  #   "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHYSJ9ywFRJ747tkhvYWFkx/Y9SkLqv3rb7T1UuXVBWo"
  # ];
  cfg = config.tensorfiles.system.zfs.disks;
  inherit (config.networking) hostName;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.system.zfs.disks = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        enable custom disk configuration
      '';
    };

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    amReinstalling = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        am I reinstalling and want to save the storage pool + keep /persist/save unused so I can restore data
      '';
    };
    zfs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      hostId = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      root = {
        #   encrypt = lib.mkOption {
        #     type = lib.types.bool;
        #     default = true;
        #   };
        #   disk1 = lib.mkOption {
        #     type = lib.types.str;
        #     default = "";
        #     description = ''
        #       device name
        #     '';
        #   };
        #   disk2 = lib.mkOption {
        #     type = lib.types.str;
        #     default = "";
        #     description = ''
        #       device name
        #     '';
        #   };
        reservation = lib.mkOption {
          type = lib.types.str;
          default = "20GiB";
          description = ''
            zfs reservation
          '';
        };
        mirror = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            mirror the zfs pool
          '';
        };
        impermanenceRoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            wipe the root directory on boot
          '';
        };
      };
      storage = {
        # enable = lib.mkOption {
        #   type = lib.types.bool;
        #   default = false;
        # };
        #   disks = lib.mkOption {
        #     type = lib.types.listOf lib.types.str;
        #     default = [];
        #     description = ''
        #       device names
        #     '';
        #   };
        #   reservation = lib.mkOption {
        #     type = lib.types.str;
        #     default = "20GiB";
        #     description = ''
        #       zfs reservation
        #     '';
        #   };
        #   mirror = lib.mkOption {
        #     type = lib.types.bool;
        #     default = false;
        #     description = ''
        #       mirror the zfs pool
        #     '';
        #   };
        # };
      };
    };
  };

  config = lib.mkMerge [
    # |----------------------------------------------------------------------| #
    (lib.mkIf cfg.zfs.enable {
      networking.hostId = cfg.zfs.hostId;
      environment.systemPackages = [pkgs.zfs-prune-snapshots];
      boot = {
        # Newest kernels might not be supported by ZFS
        kernelPackages = lib.mkForce config.boot.zfs.package.latestCompatibleLinuxPackages;
        # ZFS does not support swapfiles, disable hibernate and set cache max
        kernelParams = [
          "nohibernate"
          "zfs.zfs_arc_max=17179869184"
        ];
        supportedFilesystems = [
          "vfat"
          "zfs"
        ];
        zfs = {
          devNodes = "/dev/disk/by-id/";
          forceImportAll = true;
          requestEncryptionCredentials = true;
        };
      };
      services.zfs = {
        autoScrub.enable = true;
        trim.enable = true;
      };
    })
    # |----------------------------------------------------------------------| #
    (lib.mkIf (cfg.zfs.root.impermanenceRoot) {
      boot.initrd.postDeviceCommands =
        #wipe / and /var on boot
        lib.mkAfter ''
          zfs rollback -r zroot/root@empty
        '';
    })
    # |----------------------------------------------------------------------| #
  ];
}