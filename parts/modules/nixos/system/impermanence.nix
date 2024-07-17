# --- parts/modules/nixos/system/impermanence.nix
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
{ localFlake, inputs }:
{ config, lib, ... }:
with builtins;
with lib;
let
  inherit (localFlake.lib.tensorfiles) isModuleLoadedAndEnabled mkAgenixEnableOption;

  cfg = config.tensorfiles.system.impermanence;

  phase1Systemd = config.boot.initrd.systemd.enable;

  wipeScript = with cfg.btrfsWipe; ''
         # Reset both ${homeSubvolume} and ${rootPartition}
          # While we're tempted to just delete /${rootPartition} and create
          # a new snapshot from /${blankRootSnapshot}, /${rootPartition} is already
          # populated at this point with a number of subvolumes,
          # which makes `btrfs subvolume delete` fail.
          # So, we remove them first.
          #
          # /root contains subvolumes:
          # - /root/var/lib/portables
          # - /root/var/lib/machines
          #
          # I suspect these are related to systemd-nspawn, but
          # since I don't use it I'm not 100% sure.
          # Anyhow, deleting these subvolumes hasn't resulted
          # in any issues so far, except for fairly
          # benign-looking errors from systemd-tmpfiles.
    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "${mountpoint}/$i"
        done
        btrfs subvolume delete "$1"
    }

    # Mount drive
          mkdir -p ${mountpoint}

          # We first mount the btrfs root to ${mountpoint}
          # so we can manipulate btrfs subvolumes.
          mount -o subvol=/ ${rootPartition} ${mountpoint}

          btrfs subvolume list -o ${mountpoint}/${rootSubvolume} |
    # Move root subvolume(s) into /${oldRootSubvolume}
    if [[ -e ${mountpoint}/${rootSubvolume} ]]; then
        timestamp=$(date --date="@$(stat -c %Y ${mountpoint}/${rootSubvolume})" "+%Y-%m-%-dT%H:%M:%S")
        mkdir -p ${mountpoint}/${oldRootSubvolume}
        mv ${mountpoint}/${rootSubvolume} "${mountpoint}/${oldRootSubvolume}/$timestamp"
    fi

    # Delete root subvolumes older 30 days
    for i in $(find ${mountpoint}/${oldRootSubvolume}/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    # Delete /${homeSubvolume} if it exists
    if [[ -e ${mountpoint}/${homeSubvolume} ]]; then
        timestamp=$(date --date="@$(stat -c %Y ${mountpoint}/${homeSubvolume})" "+%Y-%m-%-dT%H:%M:%S")
        mkdir -p ${mountpoint}/${oldHomeSubvolume}
        mv ${mountpoint}/${homeSubvolume} "${mountpoint}/${oldHomeSubvolume}/$timestamp"
    fi

    # Delete home subvolumes older 30 days
    for i in $(find ${mountpoint}/${oldHomeSubvolume}/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    # Create new empty root and home subvolumes
    btrfs subvolume create ${mountpoint}/${rootSubvolume}
    btrfs subvolume create ${mountpoint}/${homeSubvolume}

    # Create a blank subvolume if it does not exist
    echo "restoring blank /${rootSubvolume} subvolume..."
    if [[ ! -e ${mountpoint}/${blankRootSnapshot} ]]; then
      btrfs subvolume snapshot -r ${mountpoint}/${rootSubvolume} ${mountpoint}/${blankRootSnapshot}
    fi
    echo "restoring blank /${homeSubvolume} subvolume..."
    if [[ ! -e ${mountpoint}/${blankHomeSnapshot} ]]; then
      btrfs subvolume snapshot -r ${mountpoint}/${homeSubvolume} ${mountpoint}/${blankHomeSnapshot}
    fi

    # Create a snapshots volume if it does not exist
    if [[ ! -e ${mountpoint}/snapshots ]]; then
      btrfs subvolume create ${mountpoint}/snapshots
    fi

          # Once we're done rolling back to a blank snapshot,
          # we can unmount ${mountpoint} and continue on the boot process.
    umount ${mountpoint}
  '';

  #hostname = config.networking.hostname;

  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in
{
  options.tensorfiles.system.impermanence = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the persistence ecosystem.
      Doing so enables other modules to automatically use the persistence instead
      of manually having to set it up yourself.
    '';

    agenix = {
      enable = mkAgenixEnableOption;
    };

    disableSudoLectures = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to disable the default sudo lectures that would be
        otherwise printed every time on login
      '';
    };

    persistentRoot = mkOption {
      type = path;
      default = "/persist";
      description = ''
        Path on the already mounted filesystem for the persistent root, that is,
        a root where we should store the persistent files and against which should
        we link the temporary files against.

        This is usually simply just /persist.
      '';
    };

    allowOther = mkOption {
      type = bool;
      default = false;
      description = ''
        TODO
      '';
    };

    btrfsWipe = {
      enable = mkEnableOption ''
        Enable btrfs based root filesystem wiping.

        This has the following requirements
        1. The user needs to have a btrfs formatted root partition (`rootPartition`)
           with a root subvolume `rootSubvolume`. This means that the whole
           system is going to reside on one partition.

           Additional decoupling can be achieved then by btrfs subvolumes.
        2. The user needs to create a blank snapshot of `rootSubvolume` during
           installation specified by `blankRootSnapshot`.

        The TL;DR of this approach is that we basically just restore the rootSubvolume
        to its initial blank snaphost.

        You can populate the root partition with any amount of desired btrfs
        subvolumes. The `rootSubvolume` is the only one required.
      '';

      rootPartition = mkOption {
        type = path;
        default = "/dev/sda1";
        description = ''
          The dev path for the main btrfs formatted root partition that is
          mentioned in the btrfsWipe.enable doc.
        '';
      };

      rootSubvolume = mkOption {
        type = str;
        default = "root";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      oldRootSubvolume = mkOption {
        type = str;
        default = "old_roots";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      blankRootSnapshot = mkOption {
        type = str;
        default = "root-blank";
        description = ''
          The btrfs snapshot of the main rootSubvolume. You will probably
          need to create this one manually during the installation & formatting
          of the system. One such way is using the following command:

          btrfs su snapshot -r /mnt/root /mnt/root-blank
        '';
      };

      homeSubvolume = mkOption {
        type = str;
        default = "home";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      oldHomeSubvolume = mkOption {
        type = str;
        default = "old_homes";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      blankHomeSnapshot = mkOption {
        type = str;
        default = "home-blank";
        description = ''
          The btrfs snapshot of the main rootSubvolume. You will probably
          need to create this one manually during the installation & formatting
          of the system. One such way is using the following command:

          btrfs su snapshot -r /mnt/root /mnt/root-blank
        '';
      };
      mountpoint = mkOption {
        type = path;
        default = "/btrfs_tmp";
        description = ''
          Temporary mountpoint that should be used for mounting and resetting
          the rootPartition.

          This is useful mainly if you want to prevent some conflicts.
        '';
      };
    };
  };

  imports = [ inputs.impermanence.nixosModules.impermanence ];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      assertions = [
        {
          assertion = hasAttr "impermanence" inputs;
          message = "Impermanence flake missing in the inputs library. Please add it to your flake inputs.";
        }
      ];
    }
    # |----------------------------------------------------------------------| #
    { fileSystems."${cfg.persistentRoot}".neededForBoot = true; }
    # |----------------------------------------------------------------------| #
    # |----------------------------------------------------------------------| #
    {
      environment.persistence = {
        "${cfg.persistentRoot}" = {
          #hideMounts = _ true;
          directories = [
            #"/etc/tensorfiles" # TODO probably not needed anymore ? not sure
            "/var/lib/bluetooth" # TODO move bluetooth to hardware
            "/var/lib/systemd/coredump"
          ];
          files = [
            "/etc/adjtime"
            "/etc/machine-id"
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf cfg.disableSudoLectures {
      security.sudo.extraConfig = mkBefore ''
        # rollback results in sudo lectures after each reboot
        Defaults lecture = never
      '';
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.btrfsWipe.enable {

      boot.initrd = {
        enable = true;
        supportedFilesystems = [ "btrfs" ];
        postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
        systemd.services.restore-root = lib.mkIf phase1Systemd {
          description = "Rollback btrfs rootfs";
          wantedBy = [ "initrd.target" ];
          requires = [ "dev-disk-by\\x2dlabel-persist.device" ];
          after = [ "dev-disk-by\\x2dlabel-persist.device" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = wipeScript;
        };
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.allowOther { programs.fuse.userAllowOther = true; })
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.identityPaths = [ "${cfg.persistentRoot}/etc/ssh/ssh_host_ed25519_key" ];

      #environment.persistence = {
      #  "${cfg.persistentRoot}" = {
      #    files = [
      #      "/etc/ssh/ssh_host_ed25519_key"
      #      "/etc/ssh/ssh_host_ed25519_key.pub"
      #    ];
      #  };
      #};
    })
    # |----------------------------------------------------------------------| #
    # {

    #   environment.persistence = {
    #     "${cfg.persistentRoot}".users.czichy = {
    #       directories = [
    #         {
    #           directory = ".ssh";
    #           mode = "0700";
    #         }
    #       ];
    #     };
    #   };
    # }
    # |----------------------------------------------------------------------| #
    {
      system.activationScripts.persistent-dirs.text =
        let
          mkHomePersist =
            user:
            lib.optionalString user.createHome ''
              mkdir -p /persist/${user.home}
              chown ${user.name}:${user.group} /persist/${user.home}
              chmod ${user.homeMode} /persist/${user.home}
            '';
          users = lib.attrValues config.users.users;
        in
        lib.concatLines (map mkHomePersist users);
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
