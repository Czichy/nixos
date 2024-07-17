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
{
  localFlake,
  secretsPath,
  pubkeys,
}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib.tensorfiles) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation.microvm.test;

  ipv4 = "10.0.0.10";
  mainGateway = "10.0.0.1";
  nameservers = [
    "119.29.29.29" # DNSPod
    "223.5.5.5" # AliDNS
  ];
  ipv4WithMask = "${ipv4}/24";
  # impermanenceCheck =
  #   (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  # impermanence =
  #   if impermanenceCheck
  #   then config.tensorfiles.system.impermanence
  #   else {};
in {
  options.tensorfiles.services.virtualisation.microvm.test = with types; {
    enable = mkEnableOption ''
      Enables Micro-VM host.
    '';

    # impermanence = {
    #   enable = mkImpermanenceEnableOption;
    # };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      microvm.vms.test = {
        autostart = true;
        restartIfChanged = true;

        specialArgs = {
          inherit localFlake;
          inherit secretsPath pubkeys;
        };

        config = {
          # imports = [import ../../networking/ssh.nix {inherit localFlake;}];

          microvm = {
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
                id = "vm-test"; # should be prefixed with "vm-"
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
            # specialArgs = {inherit localFlake config lib agenix private;};
          };
          users.users.root.password = "";
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPMF0Sz9e6JoHudF11U2F9U/S5KFINlU9556C2zA82X czichy@vmtest"
            # sshPubKey
          ];

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          systemd.network.enable = true;

          systemd.network.networks."20-lan" = {
            matchConfig.Type = "ether";
            networkConfig = {
              Address = [ipv4WithMask];
              Gateway = mainGateway;
              DNS = nameservers;
              DHCP = "no";
            };
          };
          system.stateVersion = "24.05";
        };
      };
    }
    # |----------------------------------------------------------------------| #
    # |----------------------------------------------------------------------| #
    # (mkIf impermanenceCheck {
    #   environment.persistence."${impermanence.persistentRoot}" = {
    #     directories = ["/var/lib/microvms"];
    #   };
    # })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
