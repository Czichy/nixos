{pkgs, ...}: {
  topology.self.icon = "devices.cloud-server";
  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sr_mod"
        "virtio_blk"
      ];
      kernelModules = [];
    };
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
  };

  services.fwupd.enable = true;

  # ensure snapshots_dir exists
  systemd.tmpfiles.rules = ["d /.snapshots/data/home 0755 root root - -"];

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
