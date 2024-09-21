{...}: let
  maindisk = "/dev/vda";
  disk-id = id: "/dev/disk/by-id/${id}";
  d1 = disk-id "wwn-0x5000cca25ed3025e";
  d2 = disk-id "wwn-0x5000cca25ed2e8e8";
  pool = "tank";
in {
  disko.devices = {
    disk = {
      main = {
        device = "${maindisk}";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = ["umask=0077"];
                mountpoint = "/boot";
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                inherit pool;
              };
            };
          };
        };
      };
    };
    zpool = {
      "${pool}" = {
        type = "zpool";
        rootFsOptions = {
          # https://wiki.archlinux.org/title/Install_Arch_Linux_on_ZFS
          acltype = "posixacl";
          atime = "off";
          checksum = "edonr";
          compression = "zstd";
          mountpoint = "none";
          canmount = "off";
          devices = "off";
          xattr = "sa";
          normalization = "formD";
          relatime = "on";
          "com.sun:auto-snapshot" = "false";
        };
        options = {
          ashift = "12";
          autotrim = "on";
        };

        # Take a snapshot of the empty pool
        # this will let us delete darlings
        postCreateHook = ''
          zfs list -t snapshot -H -o name \
            | grep -E '^${pool}@blank$' \
            || zfs snapshot ${pool}@blank
        '';

        datasets = {
          reserved = {
            options = {
              canmount = "off";
              mountpoint = "none";
              reservation = "20GiB";
              # reservation = "${cfg.zfs.root.reservation}";
            };
            type = "zfs_fs";
          };
          etcssh = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/etc/ssh";
            options."com.sun:auto-snapshot" = "false";
            postCreateHook = "zfs snapshot ${pool}/etcssh@blank";
          };
          persist = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/persist";
            options."com.sun:auto-snapshot" = "false";
            postCreateHook = "zfs snapshot ${pool}/persist@blank";
          };
          persistSave = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/persist/save";
            options."com.sun:auto-snapshot" = "false";
            postCreateHook = "zfs snapshot ${pool}/persistSave@blank";
          };
          nix = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
            options = {
              # Nix does not use atime (impure)
              # might as well turn it off
              atime = "off";
              canmount = "on";
              "com.sun:auto-snapshot" = "false";
            };
            postCreateHook = "zfs snapshot ${pool}/nix@blank";
          };
          root = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            options."com.sun:auto-snapshot" = "false";
            mountpoint = "/";
            postCreateHook = "zfs snapshot ${pool}/root@blank";
          };
        };
      };
    };
  };
  # Needed for agenix.
  # nixos-anywhere currently has issues with impermanence so agenix keys are lost during the install process.
  # as such we give /etc/ssh its own zfs dataset rather than using impermanence to save the keys when we wipe the root directory on boot
  # agenix needs the keys available before the zfs datasets are mounted, so we need this to make sure they are available.
  fileSystems."/etc/ssh".neededForBoot = true;
  # Needed for impermanence, because we mount /persist/save on /persist, we need to make sure /persist is mounted before /persist/save
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/persist/save".neededForBoot = true;
}
