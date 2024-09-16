{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption literalExpression mkAgenixEnableOption types;

  cfg = config.modules.system.impermanence;
in {
  options.modules.system.impermanence = {
    enable = mkOption {
      default = cfg.root.enable || cfg.home.enable;
      readOnly = true;
      description = ''
        Internal option for deciding if Impermanence module is enabled
        based on the values of `modules.system.impermanence.root.enable`
        and `modules.system.impermanence.home.enable`.
      '';
    };

    agenix = {
      enable = mkAgenixEnableOption;
    };

    disableSudoLectures = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to disable the default sudo lectures that would be
        otherwise printed every time on login
      '';
    };

    persistentRoot = mkOption {
      type = types.path;
      default = "/persist";
      description = ''
        Path on the already mounted filesystem for the persistent root, that is,
        a root where we should store the persistent files and against which should
        we link the temporary files against.

        This is usually simply just /persist.
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
        type = types.path;
        default = "/dev/sda1";
        description = ''
          The dev path for the main btrfs formatted root partition that is
          mentioned in the btrfsWipe.enable doc.
        '';
      };

      rootSubvolume = mkOption {
        type = types.str;
        default = "root";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      oldRootSubvolume = mkOption {
        type = types.str;
        default = "old_roots";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      blankRootSnapshot = mkOption {
        type = types.str;
        default = "root-blank";
        description = ''
          The btrfs snapshot of the main rootSubvolume. You will probably
          need to create this one manually during the installation & formatting
          of the system. One such way is using the following command:

          btrfs su snapshot -r /mnt/root /mnt/root-blank
        '';
      };

      homeSubvolume = mkOption {
        type = types.str;
        default = "home";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      oldHomeSubvolume = mkOption {
        type = types.str;
        default = "old_homes";
        description = ''
          The main root btrfs subvolume path that is going to be reset to
          blankRootSnapshot later.
        '';
      };

      blankHomeSnapshot = mkOption {
        type = types.str;
        default = "home-blank";
        description = ''
          The btrfs snapshot of the main rootSubvolume. You will probably
          need to create this one manually during the installation & formatting
          of the system. One such way is using the following command:

          btrfs su snapshot -r /mnt/root /mnt/root-blank
        '';
      };
      mountpoint = mkOption {
        type = types.path;
        default = "/btrfs_tmp";
        description = ''
          Temporary mountpoint that should be used for mounting and resetting
          the rootPartition.

          This is useful mainly if you want to prevent some conflicts.
        '';
      };
    };

    root = {
      enable = mkEnableOption ''
        the Impermanence module for persisting important state directories.
        By default, Impermanence will not touch user's $HOME, which is not
        ephemeral unlike root.
      '';

      allowOther = mkOption {
        type = types.bool;
        default = false;
        description = ''
          TODO
        '';
      };

      extraFiles = mkOption {
        default = [];
        example = literalExpression ''["/etc/nix/id_rsa"]'';
        description = ''
          Additional files in the root to link to persistent storage.
        '';
      };

      extraDirectories = mkOption {
        default = [];
        example = literalExpression ''["/var/lib/libvirt"]'';
        description = ''
          Additional directories in the root to link to persistent
          storage.
        '';
      };
    };

    home = {
      enable = mkEnableOption ''
        the Impermanence module for persisting important state directories.
        This option will also make user's home ephemeral, on top of the root subvolume
      '';

      allowOther = mkOption {
        type = types.bool;
        default = true;
        description = ''
          TODO
        '';
      };

      mountDotfiles = mkOption {
        default = true;
        description = ''
          Whether the repository with my configuration flake should be bound to a location
          in $HOME after a rebuild. It will symlink ''${self} to ~/.config/nyx where I
          usually put my configuration files
        '';
      };

      extraFiles = mkOption {
        default = [];
        example = literalExpression ''
          [
            ".gnupg/pubring.kbx"
            ".gnupg/sshcontrol"
            ".gnupg/trustdb.gpg"
            ".gnupg/random_seed"
          ]
        '';
        description = ''
          Additional files in the home directory to link to persistent
          storage.
        '';
      };

      extraDirectories = mkOption {
        default = [];
        example = literalExpression ''[".config/gsconnect"]'';
        description = ''
          Additional directories in the home directory to link to
          persistent storage.
        '';
      };
    };
  };
}
