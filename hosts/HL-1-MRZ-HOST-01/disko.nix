{inputs, ...}: let
  inherit (inputs.self) lib;
  disk-id = id: "/dev/disk/by-id/${id}";
  disks = {
    main = {
      name = "main";
      path = null;
      id = "nvme-Force_MP510_1945823800012888371B";
    };

    hdd1_1 = {
      name = "hdd1_1";
      path = null;
      id = "wwn-0x5000c500e95e6764";
    };
    hdd1_2 = {
      name = "hdd1_2";
      path = null;
      id = "wwn-0x5000c500e961274e";
    };
  };
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = disk-id "${disks.main.id}";
        content = {
          type = "gpt";
          partitions = {
            ESP = lib.disko.gpt.partEfi "1G";
            rpool = lib.disko.gpt.partLuksZfs disks.main.name "rpool" "100%";
          };
        };
      };
      hdd1_1 = {
        type = "disk";
        device = disk-id "${disks.hdd1_1.id}";
        content = lib.disko.content.luksZfs disks.hdd1_1.name "storage";
      };
      hdd1_2 = {
        type = "disk";
        device = disk-id "${disks.hdd1_2.id}";
        content = lib.disko.content.luksZfs disks.hdd1_2.name "storage";
      };
    };
    zpool = {
      rpool = lib.disko.zfs.mkZpool {
        datasets =
          lib.disko.zfs.impermanenceZfsDatasets "rpool"
          // {
            "safe/guests" = lib.disko.zfs.unmountable;
          };
      };
      storage = lib.disko.zfs.mkZpool {
        mode = "mirror";
        datasets = {
          "safe/guests" = lib.disko.zfs.unmountable;
        };
      };
    };
  };
  boot.initrd.systemd.services."zfs-import-rpool".after = ["cryptsetup.target"];
  boot.initrd.systemd.services."zfs-import-storage".after = ["cryptsetup.target"];
  services.zrepl = {
    enable = true;
    settings = {
      global = {
        logging = [
          {
            type = "syslog";
            level = "info";
            format = "human";
          }
        ];
        # TODO zrepl monitor
        #monitoring = [
        #  {
        #    type = "prometheus";
        #    listen = ":9811";
        #    listen_freebind = true;
        #  }
        #];
      };

      jobs = [
        {
          name = "local-snapshots";
          type = "snap";
          filesystems = {
            "rpool/local/state<" = true;
            "rpool/safe<" = true;
            "storage/safe<" = true;
            "storage/bunker<" = true;
          };
          snapshotting = {
            type = "periodic";
            prefix = "zrepl-";
            timestamp_format = "iso-8601";
            interval = "15m";
          };
          pruning.keep = [
            # Keep all manual snapshots
            {
              type = "regex";
              regex = "^zrepl-.*$";
              negate = true;
            }
            # Keep last n snapshots
            {
              type = "last_n";
              regex = "^zrepl-.*$";
              count = 10;
            }
            # Prune periodically
            {
              type = "grid";
              regex = "^zrepl-.*$";
              grid = lib.concatStringsSep " | " [
                "72x1h"
                "90x1d"
                "60x1w"
                "24x30d"
              ];
            }
          ];
        }
      ];
    };
  };
  # Needed for agenix.
  # nixos-anywhere currently has issues with impermanence so agenix keys are lost during the install process.
  # as such we give /etc/ssh its own zfs dataset rather than using impermanence to save the keys when we wipe the root directory on boot
  # agenix needs the keys available before the zfs datasets are mounted, so we need this to make sure they are available.
  # fileSystems."/etc/ssh".neededForBoot = true;
  # Needed for impermanence, because we mount /persist/save on /persist, we need to make sure /persist is mounted before /persist/save
  fileSystems."/persist".neededForBoot = true;
  # fileSystems."/persist/save".neededForBoot = true;
}
