{
  inputs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  # inherit
  #   (lib)
  #   hasAttr
  #   mkBefore
  #   mkMerge
  #   mkIf
  #   isModuleLoadedAndEnabled
  #   ;
  cfg = config.modules.system.impermanence;

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

  agenixCheck = (isModuleLoadedAndEnabled config "security.agenix") && cfg.agenix.enable;
in {
  imports = with inputs; [
    impermanence.nixosModules.impermanence
  ];

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
    {fileSystems."${cfg.persistentRoot}".neededForBoot = true;}
    # |----------------------------------------------------------------------| #
    # |----------------------------------------------------------------------| #
    {
      environment.persistence = {
        "${cfg.persistentRoot}" = {
          #hideMounts = _ true;
          directories = [
            "/var/lib/bluetooth" # TODO move bluetooth to hardware
            "/var/lib/systemd/coredump"
            # "/var/lib/nixos"
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
        supportedFilesystems = ["btrfs"];
        postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
        systemd.services.restore-root = lib.mkIf phase1Systemd {
          description = "Rollback btrfs rootfs";
          wantedBy = ["initrd.target"];
          requires = ["dev-disk-by\\x2dlabel-persist.device"];
          after = ["dev-disk-by\\x2dlabel-persist.device"];
          before = ["sysroot.mount"];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = wipeScript;
        };
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.root.allowOther {programs.fuse.userAllowOther = true;})
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.identityPaths = ["${cfg.persistentRoot}/etc/ssh/ssh_host_ed25519_key"];

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
      system.activationScripts.persistent-dirs.text = let
        mkHomePersist = user:
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

  # config = mkIf cfg.enable {
  #   users = {
  #     # this option makes it that users are not mutable outside our configurations
  #     # if you are on nixos, you are probably smart enough to not try and edit users
  #     # manually outside your configuration.nix or whatever
  #     # P.S: This option requires you to define a password file for your users
  #     # inside your configuration.nix - you can generate this password with
  #     # mkpasswd -m sha-512 > /persist/passwords/czichy after you confirm /persist/passwords exists
  #     mutableUsers = false;

  #     # each existing user needs to have a passwordFile defined here
  #     # otherwise, they will not be available for a login
  #     users = {
  #       root = {
  #         # passwordFile needs to be in a volume marked with `neededForBoot = true`
  #         hashedPasswordFile = "/persist/passwords/root";
  #       };
  #       czichy = {
  #         hashedPasswordFile = "/persist/passwords/czichy";
  #       };
  #     };
  #   };

  #   # home.persistence."/persist/home/czichy" = {};
  #   environment.persistence."/persist" = {
  #     directories =
  #       [
  #         "/etc/nixos"
  #         "/etc/nix"
  #         "/etc/NetworkManager/system-connections"
  #         "/etc/secureboot"
  #         "/var/db/sudo"
  #         "/var/lib/flatpak"
  #         "/var/lib/libvirt"
  #         "/var/lib/bluetooth"
  #         "/var/lib/nixos"
  #         "/var/lib/pipewire"
  #         "/var/lib/systemd/coredump"
  #         "/var/cache/tailscale"
  #         "/var/lib/tailscale"
  #       ]
  #       ++ [config.programs.ccache.cacheDir];

  #     files = [
  #       # important state
  #       "/etc/machine-id"
  #       # ssh stuff
  #       /*
  #       "/etc/ssh/ssh_host_ed25519_key"
  #       "/etc/ssh/ssh_host_ed25519_key.pub"
  #       "/etc/ssh/ssh_host_rsa_key"
  #       "/etc/ssh/ssh_host_rsa_key.pub"
  #       */
  #       # other
  #       # TODO: optionalstring for /var/lib/${lxd, docker}
  #     ];

  #     # builtins.concatMap (key: [key.path (key.path + ".pub")]) config.services.openssh.hostKeys
  #   };

  #   # for some reason *this* is what makes networkmanager not get screwed completely instead of the impermanence module
  #   systemd.tmpfiles.rules = [
  #     "L /var/lib/NetworkManager/secret_key - - - - /persist/var/lib/NetworkManager/secret_key"
  #     "L /var/lib/NetworkManager/seen-bssids - - - - /persist/var/lib/NetworkManager/seen-bssids"
  #     "L /var/lib/NetworkManager/timestamps - - - - /persist/var/lib/NetworkManager/timestamps"
  #   ];

  #   services.openssh.hostKeys = mkForce [
  #     {
  #       bits = 4096;
  #       path = "/persist/etc/ssh/ssh_host_rsa_key";
  #       type = "rsa";
  #     }
  #     {
  #       bits = 4096;
  #       path = "/persist/etc/ssh/ssh_host_ed25519_key";
  #       type = "ed25519";
  #     }
  #   ];

  #   boot.initrd.systemd.services.rollback = {
  #     description = "Rollback BTRFS root subvolume to a pristine state";
  #     wantedBy = ["initrd.target"];
  #     # make sure it's done after encryption
  #     # i.e. LUKS/TPM process
  #     after = ["systemd-cryptsetup@enc.service"];
  #     # mount the root fs before clearing
  #     before = ["sysroot.mount"];
  #     unitConfig.DefaultDependencies = "no";
  #     serviceConfig.Type = "oneshot";
  #     script = ''
  #       mkdir -p /mnt

  #       # We first mount the btrfs root to /mnt
  #       # so we can manipulate btrfs subvolumes.
  #       mount -o subvol=/ /dev/mapper/enc /mnt

  #       # If home is meant to be impermanent, also mount the home subvolume to be deleted later
  #       ${optionalString cfg.home.enable "mount -o subvol=/home /dev/mapper/enc /mnt/home"}

  #       # While we're tempted to just delete /root and create
  #       # a new snapshot from /root-blank, /root is already
  #       # populated at this point with a number of subvolumes,
  #       # which makes `btrfs subvolume delete` fail.
  #       # So, we remove them first.
  #       #
  #       # /root contains subvolumes:
  #       # - /root/var/lib/portables
  #       # - /root/var/lib/machines

  #       btrfs subvolume list -o /mnt/root |
  #         cut -f9 -d' ' |
  #         while read subvolume; do
  #           echo "deleting /$subvolume subvolume..."
  #           btrfs subvolume delete "/mnt/$subvolume"
  #         done &&
  #         echo "deleting /root subvolume..." &&
  #         btrfs subvolume delete /mnt/root

  #       echo "restoring blank /root subvolume..."
  #       btrfs subvolume snapshot /mnt/root-blank /mnt/root

  #       ${optionalString cfg.home.enable ''
  #         echo "restoring blank /home subvolume..."
  #         mount -o subvol=/home /dev/mapper/enc /mnt/home
  #       ''}

  #       # Once we're done rolling back to a blank snapshot,
  #       # we can unmount /mnt and continue on the boot process.
  #       umount /mnt
  #     '';
  #   };

  #   assertions = [
  #     {
  #       assertion = cfg.home.enable -> !cfg.root.enable;
  #       message = ''
  #         You have enabled home impermanence without root impermanence. This
  #         is not supported due to the fact that we handle all all impermanence
  #         related deletions and creations in a single service. Please enable
  #         `modules.system.impermanence.root.enable` if you wish to proceed.
  #       '';
  #     }
  #   ];

  #   # home impermanence is not very safe, and chances are I don't want it. Warn any potential
  #   # users (which may or may not be me) when it is enabled just to be safe.
  #   # p.s. I really don't like nix's warnings syntax. why can't it be the same
  #   # as the assertions format? /rant
  #   warnings =
  #     if cfg.home.enable
  #     then ["Home impermanence is enabled. This is experimental, beware."]
  #     else [];
  # };
}
