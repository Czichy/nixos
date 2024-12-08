{
  inputs,
  pkgs,
  hostName,
  ...
}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
  microvm.mem = 512;
  microvm.vcpu = 1;
  # microvm.devices = [
  #   {
  #     # Lesekopf - Silicon_Labs_CP2104_USB_to_UART_Bridge_Controller_015ACA59
  #     bus = "usb";
  #     path = "vendorid=0x10c4,productid=0xea60";
  #   }
  # ];
  microvm.qemu.extraArgs = [
    "-device"
    "qemu-xhci"
    "-device"
    "usb-host,vendorid=0x10c4,productid=0xea60"
  ];
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;

  networking.firewall = {
    allowedTCPPorts = [80 443 3000];
  };
  # |----------------------------------------------------------------------| #
  users = {
    users.power = {
      isSystemUser = true;
      group = "power";
    };
    groups.power = {};
  };
  # |----------------------------------------------------------------------| #
  # | SYSTEM PACKAGES |
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    pkg-config
    pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
    usbutils # Tools for working with USB devices, such as lsusb
    minicom # Modem control and terminal emulation program
    inputs.power-meter.packages.${pkgs.system}.power-meter
  ];
  # |----------------------------------------------------------------------| #
  systemd.services.interosEsMdb = {
    description = "Power Meter";
    # after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      # change this to refer to your actual derivation
      ExecStart = "/run/current-system/sw/bin/power-meter --port /dev/ttyUSB0";
      # EnvironmentFile = "${interosEsMdb}/lib/es-service.env";
      Restart = "always";
      RestartSec = 1;
    };
  };
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/root/.local/share/power-meter/";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #
}
