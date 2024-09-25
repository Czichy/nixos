{inputs, ...}: let
  inherit (inputs.self) lib;
  disk-path = id: "/dev/disk/by-path/${id}";
  disks = {
    main = {
      name = "main";
      path = "pci-0000:00:10.0";
    };
  };
  # luksName = "zfs";
  pool = "tank";
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk-path "${disks.main.path}";
        content = {
          type = "gpt";
          partitions = {
            # grub = lib.disko.gpt.partGrub;
            ESP = lib.disko.gpt.partEfi "1G";
            root = lib.disko.gpt.partLuksZfs disks.main.name "${pool}" "100%";
          };
        };
      };
    };
    zpool = {
      "${pool}" = lib.disko.zfs.mkZpool {datasets = lib.disko.zfs.impermanenceZfsDatasets "${pool}";};
    };
  };

  # Construct the partition table for the system's primary disk.
  # disko.devices.disk.main = {
  #   type = "disk";
  #   device = "/dev/vda";
  #   content = {
  #     type = "table";
  #     format = "gpt";
  #     partitions = [
  #       # Create a large boot partition.
  #       #
  #       # NixOS creates a separate boot entry for each generation, which
  #       # can fill up the partition faster than other operating systems.
  #       #
  #       # Storage is cheap, so this can be more generous than necessary.
  #       {
  #         name = "ESP";
  #         start = "1MiB";
  #         end = "512MiB";
  #         bootable = true;
  #         content = {
  #           type = "filesystem";
  #           format = "vfat";
  #           mountpoint = "/boot";
  #           mountOptions = ["defaults"];
  #         };
  #       }
  #       # Partition the remainder of the disk as a LUKS container.
  #       #
  #       # This system should be able to boot without manual intervention, so
  #       # the LUKS container will be set up to use a random segment data from
  #       # an external device constructed in a separate step.
  #       {
  #         name = "luks";
  #         start = "512MiB";
  #         end = "100%";
  #         content = {
  #           type = "luks";
  #           name = "CRYPT";
  #           content = {
  #             type = "zfs";
  #             pool = "tank";
  #           };
  #         };
  #       }
  #     ];
  #   };
  # };

  # Construct the primary ZFS pool for this system.
  # disko.devices.zpool.tank = {
  #   type = "zpool";

  #   options = {
  #     ashift = "12";
  #     autotrim = "on";
  #     listsnapshots = "on";
  #   };

  #   rootFsOptions = {
  #     acltype = "posixacl";
  #     atime = "off";
  #     canmount = "off";
  #     compression = "zstd";
  #     dnodesize = "auto";
  #     mountpoint = "none";
  #     normalization = "formD";
  #     relatime = "on";
  #     xattr = "sa";
  #     "com.sun:auto-snapshot" = "true";
  #   };

  #   datasets = {
  #     # Static reservation so the pool will never be 100% full.
  #     #
  #     # If a pool fills up completely, delete this & reclaim space; don't
  #     # forget to re-create it afterwards!
  #     reservation = {
  #       type = "zfs_fs";
  #       options = {
  #         canmount = "off";
  #         mountpoint = "none";
  #         refreservation = "2G";
  #         primarycache = "none";
  #         secondarycache = "none";
  #       };
  #     };

  #     # Root filesystem.
  #     root = {
  #       type = "zfs_fs";
  #       mountpoint = "/";
  #       options = {
  #         mountpoint = "legacy";
  #         secondarycache = "none";
  #         "com.sun:auto-snapshot" = "true";
  #       };
  #     };

  #     # `/nix/store` dataset; no snapshots required.
  #     nix = {
  #       type = "zfs_fs";
  #       mountpoint = "/nix";
  #       options = {
  #         mountpoint = "legacy";
  #         relatime = "off";
  #         secondarycache = "none";
  #         "com.sun:auto-snapshot" = "false";
  #       };
  #     };

  #     # User filesystem.
  #     home = {
  #       type = "zfs_fs";
  #       mountpoint = "/home";
  #       options = {
  #         mountpoint = "legacy";
  #         secondarycache = "none";
  #         "com.sun:auto-snapshot" = "true";
  #       };
  #     };

  #     # `journald` log.
  #     systemd-logs = {
  #       type = "zfs_fs";
  #       mountpoint = "/var/log";
  #       options = {
  #         mountpoint = "legacy";
  #         secondarycache = "none";
  #         "com.sun:auto-snapshot" = "false";
  #       };
  #     };
  #   };
  # };

  boot.initrd.systemd.services."zfs-import-${pool}".after = ["cryptsetup.target"];

  # Now this is hairy! The format is more or less:
  # IP:<ignore>:GATEWAY:NETMASK:HOSTNAME:NIC:AUTCONF?
  # See: https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
  # boot.kernelParams = ["ip=1.2.3.4::1.2.3.1:255.255.255.192:myhostname:enp35s0:off"];
  # boot.loader.grub.devices = ["/dev/disk/by-id/${disks.main}"];
  # disko.devices = {
  #   disk = {
  #     main = {
  #       device = disk-path "${disks.main.path}";
  #       type = "disk";
  #       content = {
  #         type = "gpt";
  #         partitions = {
  #           ESP = {
  #             size = "1G";
  #             type = "EF00";
  #             content = {
  #               type = "filesystem";
  #               format = "vfat";
  #               mountOptions = ["umask=0077"];
  #               mountpoint = "/boot";
  #             };
  #           };
  #           luksZfs = {
  #             type = "8300";
  #             size = "100%";
  #             content = {
  #               type = "luks";
  #               name = "${pool}_${luksName}";
  #               askPassword = true;
  #               settings = {
  #                 #                keyFile = "/dev/mapper/cryptkey";
  #                 #               keyFileSize = 8192;
  #                 # fallbackToPassword = true;
  #                 allowDiscards = true;
  #               };
  #               content = {
  #                 type = "zfs";
  #                 inherit pool;
  #               };
  #             };
  #           };
  #         };
  #       };
  #     };
  #   };
  #   zpool = {
  #     "${pool}" = {
  #       type = "zpool";
  #       rootFsOptions = {
  #         acltype = "posixacl";
  #         atime = "off";
  #         checksum = "edonr";
  #         compression = "zstd";
  #         mountpoint = "none";
  #         canmount = "off";
  #         devices = "off";
  #         xattr = "sa";
  #         normalization = "formD";
  #         relatime = "on";
  #         "com.sun:auto-snapshot" = "false";
  #       };
  #       options = {
  #         ashift = "12";
  #         autotrim = "on";
  #       };

  #       postCreateHook = ''
  #         zfs list -t snapshot -H -o name \
  #           | grep -E '^${pool}@blank$' \
  #           || zfs snapshot ${pool}@blank
  #       '';

  #       datasets = {
  #         reserved = {
  #           options = {
  #             canmount = "off";
  #             mountpoint = "none";
  #             reservation = "20GiB";
  #           };
  #           type = "zfs_fs";
  #         };
  #         safe = {
  #           options = {
  #             canmount = "off";
  #             mountpoint = "none";
  #           };
  #           type = "zfs_fs";
  #         };
  #         "safe/persist" = {
  #           type = "zfs_fs";
  #           options.mountpoint = "legacy";
  #           mountpoint = "/persist";
  #           options."com.sun:auto-snapshot" = "false";
  #           # postCreateHook = "zfs snapshot ${pool}/persistSave@blank";
  #         };
  #         local = {
  #           options = {
  #             canmount = "off";
  #             mountpoint = "none";
  #           };
  #           type = "zfs_fs";
  #         };
  #         "local/nix" = {
  #           type = "zfs_fs";
  #           options.mountpoint = "legacy";
  #           mountpoint = "/nix";
  #           options = {
  #             atime = "off";
  #             canmount = "on";
  #             "com.sun:auto-snapshot" = "false";
  #           };
  #           # postCreateHook = "zfs snapshot ${pool}/local/nix@blank";
  #         };
  #         "local/root" = {
  #           type = "zfs_fs";
  #           options.mountpoint = "legacy";
  #           options."com.sun:auto-snapshot" = "false";
  #           mountpoint = "/";
  #           #             postCreateHook = "zfs snapshot ${pool}/root@blank";
  #         };
  #         "local/state" = {
  #           type = "zfs_fs";
  #           options.mountpoint = "legacy";
  #           mountpoint = "/state";
  #           options = {
  #             atime = "off";
  #             canmount = "on";
  #             "com.sun:auto-snapshot" = "false";
  #           };
  #           # postCreateHook = "zfs snapshot ${pool}/local/nix@blank";
  #         };
  #       };
  #     };
  #   };
  # };
  # Needed for agenix.
  # nixos-anywhere currently has issues with impermanence so agenix keys are lost during the install process.
  # as such we give /etc/ssh its own zfs dataset rather than using impermanence to save the keys when we wipe the root directory on boot
  # agenix needs the keys available before the zfs datasets are mounted, so we need this to make sure they are available.
  # fileSystems."/etc/ssh".neededForBoot = true;
  # Needed for impermanence, because we mount /persist/save on /persist, we need to make sure /persist is mounted before /persist/save
  fileSystems."/persist".neededForBoot = true;
  # fileSystems."/persist/save".neededForBoot = true;
}
