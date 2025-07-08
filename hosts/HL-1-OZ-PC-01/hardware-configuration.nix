{
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  environment.systemPackages = with pkgs; [
    libva-utils
    lm_sensors
  ];

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
        # "nvidia"
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

  # services.udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";

  hardware = {
    enableAllFirmware = true;
    cpu.amd.updateMicrocode = true;
    opengl.enable = true;

    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
  };

  # fancontrol stuff
  # systemd.services.fancontrol = {
  #   description = "Start fancontrol, if configured";
  #   wantedBy = ["multi-user.target"];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.lm_sensors}/sbin/fancontrol";
  #   };
  # };

  # environment.etc."fancontrol".text = ''
  #   INTERVAL=10
  #   FCTEMPS=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/temp1_input /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/temp7_input
  #   FCFANS=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/fan2_input /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/fan1_input
  #   MINTEMP=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=35 /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=30
  #   MAXTEMP=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=70 /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=60
  #   MINSTART=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=4 /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=75
  #   MINSTOP=/sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm2=0 /sys/devices/platform/nct6775.2560/hwmon/hwmon[[:print:]]*/pwm1=60
  # '';
}
