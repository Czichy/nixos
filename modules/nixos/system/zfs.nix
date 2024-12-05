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
  cfg = config.tensorfiles.system.zfs;
  inherit (config.networking) hostName;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.system.zfs = {
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
    hostId = lib.mkOption {
      type = lib.types.str;
      default = builtins.substring 0 8 (builtins.hashString "md5" hostName);
    };
    rootPool = lib.mkOption {
      type = lib.types.str;
      default = "tank";
    };
  };

  config = lib.mkMerge [
    # |----------------------------------------------------------------------| #
    (lib.mkIf cfg.enable {
      networking.hostId = cfg.hostId;
      environment.systemPackages = with pkgs; [zfs-prune-snapshots zfs];
      boot = {
        # Newest kernels might not be supported by ZFS
        kernelPackages = lib.mkForce pkgs.linuxPackagesFor (pkgs.linuxKernel.kernels.linux_6_6.override {
          argsOverride = rec {
            src = pkgs.fetchurl {
              url = "mirror://kernel/linux/kernel/v${lib.versions.major version}.x/linux-${version}.tar.xz";
              sha256 = "sha256-VeW8vGjWZ3b8RolikfCiSES+tXgXNFqFTWXj0FX6Qj4=";
            };
            version = "6.10.14";
            modDirVersion = "6.10.14";
          };
        });
        # kernelPackages = lib.mkForce config.boot.zfs.package.latestCompatibleLinuxPackages;
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
          devNodes = "/dev/disk/by-id";
          # The root pool should never be imported forcefully.
          # Failure to import is important to notice!
          forceImportRoot = false;
          # extraPools = ["tank"];
          # forceImportAll = true;
          # requestEncryptionCredentials = true;
        };
      };
      services.zfs = {
        autoScrub = {
          enable = true;
          interval = "weekly";
        };
        trim = {
          enable = true;
          interval = "weekly";
        };
      };
    })
    # |----------------------------------------------------------------------| #
    {
      services.telegraf.extraConfig.inputs = lib.mkIf config.services.telegraf.enable {
        zfs.poolMetrics = true;
      };
    }
    # |----------------------------------------------------------------------| #
    (lib.mkIf impermanenceCheck {
      # TODO remove once this is upstreamed
      boot.initrd.systemd.services."zfs-import-${cfg.rootPool}".after = ["cryptsetup.target"];
      # After importing the rpool, rollback the root system to be empty.
      # boot.initrd.systemd.services.impermanence-root = {
      #   description = "Rollback root fs";
      #   wantedBy = ["initrd.target"];
      #   after = ["zfs-import-${cfg.rootPool}.service"];
      #   requires = ["zfs-import-${cfg.rootPool}.service"];
      #   before = ["sysroot.mount"];
      #   unitConfig.DefaultDependencies = "no";
      #   serviceConfig = {
      #     Type = "oneshot";
      #     ExecStart = "${pkgs.zfs}/bin/zfs rollback -r ${cfg.rootPool}/local/root@blank";
      #   };
      # };
      # boot.initrd.postDeviceCommands =
      #   #wipe / and /var on boot
      #   lib.mkAfter ''
      #     zfs rollback -r zroot/root@empty
      #   '';
    })
    # |----------------------------------------------------------------------| #
  ];
}
