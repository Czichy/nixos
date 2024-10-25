{inputs, ...}: let
  inherit (inputs.self) lib;
  disk-path = id: "/dev/disk/by-path/${id}";
  disks = {
    main = {
      name = "main";
      path = "pci-0000:00:10.0";
    };
  };
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
            ESP = lib.disko.gpt.partEfi "1G";
            "${pool}" = lib.disko.gpt.partLuksZfs disks.main.name "${pool}" "100%";
          };
        };
      };
    };
    zpool = {
      "${pool}" = lib.disko.zfs.mkZpool {datasets = lib.disko.zfs.impermanenceZfsDatasets "${pool}";};
    };
  };
  # boot.initrd.systemd.services."zfs-import-${pool}".after = ["cryptsetup.target"];
  # Needed for agenix.
  # nixos-anywhere currently has issues with impermanence so agenix keys are lost during the install process.
  # as such we give /etc/ssh its own zfs dataset rather than using impermanence to save the keys when we wipe the root directory on boot
  # agenix needs the keys available before the zfs datasets are mounted, so we need this to make sure they are available.
  # fileSystems."/etc/ssh".neededForBoot = true;
  # Needed for impermanence, because we mount /persist/save on /persist, we need to make sure /persist is mounted before /persist/save
  fileSystems."/persist".neededForBoot = true;
  # fileSystems."/persist/save".neededForBoot = true;
}
