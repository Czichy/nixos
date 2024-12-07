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
  microvm.devices = [
    # Lesekopf - Silicon_Labs_CP2104_USB_to_UART_Bridge_Controller_015ACA59
    {
      bus = "usb";
      path = "serial=015ACA59,model=CP2104_USB_to_UART_Bridge_Controller";
    }
  ];
  # microvm.shares = [
  #   {
  #     # On the host
  #     source = "/shared/shares/users/christian/Trading/TWS_Flex_Reports";
  #     # In the MicroVM
  #     mountPoint = "/TWS_Flex_Reports";
  #     tag = "flex";
  #     proto = "virtiofs";
  #   }
  # ];

  networking.hostName = hostName;

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
    minicom # Modem control and terminal emulation program
    inputs.power-meter.packages.${pkgs.system}.power-meter
  ];
  # |----------------------------------------------------------------------| #
  # systemd.timers."ibkr-flex-download" = {
  #   wantedBy = ["timers.target"];
  #   timerConfig = {
  #     Perisistent = true;
  #     OnCalendar = "Mon..Fri 23:30";
  #     Unit = "ibkr-flex-download.service";
  #   };
  # };

  # systemd.services."ibkr-flex-download" = {
  #   serviceConfig = {
  #     Type = "simple";
  #     User = "root";
  #     ExecStart = "${download-ibkr-flex}/bin/ibkr-flex-download";
  #   };
  # };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
