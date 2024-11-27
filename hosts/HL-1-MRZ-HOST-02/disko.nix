# --- parts/hosts/spinorbundle/disko.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
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
