let
  rawdisk = "/dev/nvme1n1";
in {
  disko.devices = {
    nodev = {
      "/" = {
        # May need to replace with btrfs snapshots if I use more than 8G?
        fsType = "tmpfs";
        mountOptions = ["defaults" "size=2G" "mode=755"];
      };
      "/home/czichy" = {
        # May need to replace with btrfs snapshots if I use more than 8G?
        fsType = "tmpfs";
        mountOptions = ["defaults" "size=2G" "mode=777"];
      };
    };
    disk = {
      ${rawdisk} = {
        device = "${rawdisk}";
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            boot = {
              priority = 1;
              name = "desktop_esp";
              label = "desktop_esp";
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            root = {
              # label = "${config.networking.hostName}_persist";
              label = "desktop_persist";
              name = "btrfs";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  # "-L ${config.networking.hostName}_persist"
                  "-L desktop_persist"
                ];
                subvolumes = {
                  nix = {
                    type = "filesystem";
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd"];
                  };
                  "@persist" = {
                    type = "filesystem";
                    mountpoint = "/persist";
                    mountOptions = ["compress=zstd"];
                  };
                  # shared = {
                  #   type = "filesystem";
                  #   mountpoint = "/shared";
                  #   mountOptions = ["compress=zstd"];
                  # };
                  # log = {
                  #   type = "filesystem";
                  #   mountpoint = "/var/log";
                  #   mountOptions = ["compress=zstd"];
                  # };
                };
              };
            };
          };
        };
      };
    };
  };
}
