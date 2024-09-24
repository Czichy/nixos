{lib, ...}: let
  disko = {
    content = {
      luksZfs = luksName: pool: {
        type = "luks";
        name = "${pool}_${luksName}";
        settings.allowDiscards = true;
        content = {
          type = "zfs";
          inherit pool;
        };
      };
    };
    gpt = rec {
      partGrub = {
        priority = 1;
        size = "1M";
        type = "ef02";
      };
      partEfi = size: {
        inherit size;
        priority = 1000;
        type = "EF00";
        content = {
          type = "filesystem";
          mountOptions = ["umask=0077"];
          format = "vfat";
          mountpoint = "/boot";
        };
      };
      partBoot = size:
        partEfi size
        // {
          hybrid.mbrBootableFlag = true;
        };
      partSwap = size: {
        inherit size;
        priority = 2000;
        content = {
          type = "swap";
          randomEncryption = true;
        };
      };
      partLuksZfs = luksName: pool: size: {
        inherit size;
        content = disko.content.luksZfs luksName pool;
      };
    };
    zfs = rec {
      mkZpool = lib.recursiveUpdate {
        type = "zpool";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          atime = "off";
          xattr = "sa";
          dnodesize = "auto";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
        };
        options = {
          ashift = "12";
          autotim = "on";
        };
      };

      impermanenceZfsDatasets = pool: {
        "local" = unmountable;
        "local/root" =
          filesystem "/"
          // {
            postCreateHook = "zfs snapshot ${pool}/local/root@blank";
          };
        "local/nix" = filesystem "/nix";
        "local/state" = filesystem "/state";
        "safe" = unmountable;
        "safe/persist" = filesystem "/persist";
      };

      unmountable = {type = "zfs_fs";};
      filesystem = mountpoint: {
        type = "zfs_fs";
        options = {
          canmount = "noauto";
          "com.sun:auto-snapshot" = "false";
          inherit mountpoint;
        };
        # Required to add dependencies for initrd
        inherit mountpoint;
      };
    };
  };
in {inherit disko;}
