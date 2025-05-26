{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  environment.systemPackages = with pkgs; [libva-utils];

  # networking.useDHCP = lib.mkDefault true;

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [
        "kvm-amd"
        "nvidia"
        "amdgpu"
        "i2c-dev"
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
    # NOTE: Add "rd.systemd.unit=rescue.target" to debug initrd
    kernelParams = ["log_buf_len=16M"]; # must be {power of two}[KMG]
    tmp.useTmpfs = true;
  };

  programs.gamemode.enable = true;
  console.earlySetup = true;
  services.fwupd.enable = true;

  # BTRFS stuff
  # Scrub btrfs to protect data integrity
  services.btrfs.autoScrub.enable = true;

  services.btrbk.instances."btrbk" = {
    onCalendar = "*:0/10";
    settings = {
      snapshot_preserve = "14d";
      snapshot_preserve_min = "2d";

      target_preserve_min = "no";
      target_preserve = "no";

      preserve_day_of_week = "monday";
      timestamp_format = "long-iso";
      snapshot_create = "onchange";

      volume."/" = {
        subvolume = {
          "home" = {
            snapshot_dir = "/.snapshots/data/home";
          };
        };
      };
    };
  };

  # ensure snapshots_dir exists
  systemd.tmpfiles.rules = ["d /.snapshots/data/home 0755 root root - -"];

  boot = {
    loader = {
      timeout = 1;
      grub.enable = false;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };
    #binfmt.emulatedSystems = [ "aarch64-linux" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  services.hardware.openrgb.enable = true;

  services.udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";

  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    nvidia = {
      open = true;
      nvidiaSettings = true;
    };
  };
  services.xserver.videoDrivers = ["nvidia"];
}
