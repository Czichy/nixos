{
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  #environment.systemPackages = with pkgs; [ libva-utils ];
  boot = {
    initrd = {
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sdhci_pci"
      ];
      kernelModules = [
        "i2c-dev"
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
        # "vfio_virqfd"
        "xhci_pci"
      ];

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
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
    # NOTE: Add "rd.systemd.unit=rescue.target" to debug initrd
    kernelParams = ["intel_iommu=on" "iommu=pt" "log_buf_len=16M"]; # must be {power of two}[KMG]
    tmp.useTmpfs = true;

    # loader.timeout = lib.mkDefault 2;
  };

  console.earlySetup = true;

  services.fwupd.enable = true;

  # ensure snapshots_dir exists
  systemd.tmpfiles.rules = ["d /.snapshots/data/home 0755 root root - -"];

  boot = {
    loader = {
      timeout = 2;
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
    # kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = lib.mkDefault true;
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
