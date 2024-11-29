let
  rawdisk = "/dev/nvme0n1";
in {
  disko.devices = {
    #nodev = {
    #"/" = {
    ## May need to replace with btrfs snapshots if I use more than 8G?
    #fsType = "tmpfs";
    #mountOptions = ["defaults" "size=2G" "mode=755"];
    #};
    #"/home/czichy" = {
    ## May need to replace with btrfs snapshots if I use more than 8G?
    #fsType = "tmpfs";
    #mountOptions = ["defaults" "size=2G" "mode=777"];
    #};
    #};
    disk = {
      ${rawdisk} = {
        device = "${rawdisk}";
        type = "disk";

        content = {
          type = "gpt";
          partitions = {
            boot = {
              priority = 1;
              name = "esp";
              label = "esp";
              size = "1024M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = ["umask=0077"];
                mountpoint = "/boot";
              };
            };

            root = {
              # label = "${config.networking.hostName}_persist";
              label = "persist";
              name = "btrfs";
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-f"
                  # "-L ${config.networking.hostName}_persist"
                  "-L persist"
                ];
                subvolumes = {
                  "/root" = {
                    type = "filesystem";
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/home" = {
                    type = "filesystem";
                    mountpoint = "/home";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/nix" = {
                    type = "filesystem";
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd"];
                  };
                  "/persist" = {
                    type = "filesystem";
                    mountpoint = "/persist";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/log" = {
                    type = "filesystem";
                    mountpoint = "/var/log";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/snapshots" = {
                    mountpoint = "/snapshots";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = "8G";
                  };
                  shared = {
                    type = "filesystem";
                    mountpoint = "/shared";
                    mountOptions = ["compress=zstd"];
                  };
                  log = {
                    type = "filesystem";
                    mountpoint = "/var/log";
                    mountOptions = ["compress=zstd"];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/snapshots".neededForBoot = true;
}
