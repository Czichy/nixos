{
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  topology.self.icon = "devices.cloud-server";
  boot = {
    initrd = {
      availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "virtio_pci"
        "sr_mod"
        "virtio_blk"
        "virtio_scsi"
        "virtio_net"
        "virtio_scsi"
      ];
      kernelModules = [];
      systemd = {
        enable = true;
        # emergencyAccess = globals.root.hashedPassword;
        # TODO good idea? targets.emergency.wants = ["network.target" "sshd.service"];
        extraBin.ip = "${pkgs.iproute2}/bin/ip";
        extraBin.ping = "${pkgs.iputils}/bin/ping";
        extraBin.cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";
        # Give me a usable shell please
        users.root.shell = "${pkgs.bashInteractive}/bin/bash";
        storePaths = ["${pkgs.bashInteractive}/bin/bash"];
      };
    };
    kernelModules = [];
    extraModulePackages = [];
  };

  services.fwupd.enable = true;

  boot = {
    loader = {
      timeout = 1;
      grub.enable = false;
      efi = {
        canTouchEfiVariables = true;
        # efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 8;
      };
    };
    #binfmt.emulatedSystems = [ "aarch64-linux" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware = {
    enableAllFirmware = true;
  };
}
