{inputs, ...}: let
  inherit (inputs.self) lib;
  disk-id = id: "/dev/disk/by-id/${id}";
  disks = {
    main = {
      name = "main";
      path = null;
      id = "mmc-BJTD4R_0xad934b39";
    };

    sata_1 = {
      name = "sata_1";
      path = null;
      id = "ata-Samsung_SSD_840_Series_S14JNEACC24945P";
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
      sata_1 = {
        type = "disk";
        device = disk-id "${disks.sata_1.id}";
        content = lib.disko.content.luksZfs disks.sata_1.name "storage";
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
  fileSystems."/state".neededForBoot = true;
  # boot.initrd.systemd.services."zfs-import-storage".after = ["cryptsetup.target"];
}
