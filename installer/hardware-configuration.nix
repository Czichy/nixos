{
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  #environment.systemPackages = with pkgs; [ libva-utils ];

  networking.useDHCP = lib.mkDefault true;

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

  # BTRFS stuff
  # Scrub btrfs to protect data integrity
  services.btrfs.autoScrub.enable = true;

  # services.btrbk.instances."btrbk" = {
  #   onCalendar = "*:0/10";
  #   settings = {
  #     snapshot_preserve = "14d";
  #     snapshot_preserve_min = "2d";

  #     target_preserve_min = "no";
  #     target_preserve = "no";

  #     preserve_day_of_week = "monday";
  #     timestamp_format = "long-iso";
  #     snapshot_create = "onchange";

  #     volume."/" = {
  #       subvolume = {
  #         "home" = {
  #           snapshot_dir = "/.snapshots/data/home";
  #         };
  #       };
  #     };
  #   };
  # };

  # ensure snapshots_dir exists
  systemd.tmpfiles.rules = ["d /.snapshots/data/home 0755 root root - -"];

  boot = {
    loader = {
      # timeout = 1;
      grub.enable = false;
      efi = {
        canTouchEfiVariables = true;
        # efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
    };
    #binfmt.emulatedSystems = [ "aarch64-linux" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # hardware = {
  #   enableAllFirmware = true;
  # };
  # Hardware hybrid decoding
  #nixpkgs.config.packageOverrides = pkgs: {
  #  vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  #};
}
