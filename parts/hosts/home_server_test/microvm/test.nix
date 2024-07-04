# --- parts/modules/nixos/services/networking/networkmanager.nix
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
{localFlake}: {
  config,
  lib,
  pkgs,
  microvm,
  ...
}:
with builtins;
with lib; let
  inherit (inputs.flake-parts.lib) importApply;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation.microvm.test;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.virtualisation.microvm.test = with types; {
    enable = mkEnableOption ''
      Enables Micro-VM host.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      # assertions = [
      #   {
      #     assertion = config.custom.virtualisation.vfio.enable;
      #     message = "VFIO needs to be enabled for fancontrol-microvm VM to function";
      #   }
      # ];

      microvm.vms.test = {
        autostart = true;
        restartIfChanged = true;

        specialArgs = {inherit localFlake config lib agenix private;};

        config = {
          # Any other configuration for your MicroVM
          mem = 1024; # RAM allocation in MB
          vcpu = 1; # Number of Virtual CPU cores
          # It is highly recommended to share the host's nix-store
          # with the VMs to prevent building huge images.
          # shares can not be set to `neededForBoot = true;`
          # so if you try to use a share in boot script(such as system.activationScripts), it will fail!
          shares = [
            {
              # It is highly recommended to share the host's nix-store
              # with the VMs to prevent building huge images.
              # a host's /nix/store will be picked up so that no
              # squashfs/erofs will be built for it.
              #
              # by this way, /nix/store is readonly in the VM,
              # and thus the VM can't run any command that modifies
              # the store. such as nix build, nix shell, etc...
              # if you want to run nix commands in the VM, see
              # https://github.com/astro/microvm.nix/blob/main/doc/src/shares.md#writable-nixstore-overlay
              tag = "ro-store"; # Unique virtiofs daemon tag
              proto = "virtiofs"; # virtiofs is faster than 9p
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            }
          ];

          interfaces = [
            {
              type = "tap";
              id = "vm-mitsuha"; # should be prefixed with "vm-"
              mac = "02:00:00:00:00:02"; # Unique MAC address
            }
          ];

          # Block device images for persistent storage
          # microvm use tmpfs for root(/), so everything else
          # is ephemeral and will be lost on reboot.
          #
          # you can check this by running `df -Th` & `lsblk` in the VM.
          volumes = [
            {
              mountPoint = "/var";
              image = "var.img";
              size = 512;
            }
            {
              mountPoint = "/etc";
              image = "etc.img";
              size = 50;
            }
          ];

          hypervisor = "qemu";
          # Control socket for the Hypervisor so that a MicroVM can be shutdown cleanly
          socket = "control.socket";
        };
        system.stateVersion = "24.05";

        networking.hostName = cfg.hostname;

        # ---------------------
        # | ADDITIONAL CONFIG |
        # ---------------------
        tensorfiles = {
          profiles.graphical-startx-home-manager.enable = true;
          profiles.packages-extra.enable = true;

          security.agenix.enable = true;

          services.syncthing = {
            enable = true;
            user = "czichy";
          };

          # system.users.usersSettings."root" = {
          #   agenixPassword.enable = true;
          # };
          system.users.usersSettings."czichy" = {
            isSudoer = true;
            isNixTrusted = true;
            agenixPassword.enable = true;
            extraGroups = [
              "video"
              "camera"
              "audio"
              "networkmanager"
              "input"
              "docker"
            ];
          };
        };
        users.defaultUserShell = pkgs.nushell;
        users.users.root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
          # sshPubKey
        ];

        services.openssh = {
          enable = true;
          settings.PermitRootLogin = "yes";
        };
      };
    }
    # |----------------------------------------------------------------------| #
    # (mkIf impermanenceCheck {
    #   environment.persistence."${impermanence.persistentRoot}" = {
    #     directories = ["/var/lib/microvms"];
    #   };
    # })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
