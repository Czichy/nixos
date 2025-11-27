{
  pkgs,
  inputs,
  ...
}: {
  # -----------------
  # | SPECIFICATION |
  # -----------------
  # Model: Lenovo B51-80

  # --------------------------
  # | ROLES & MODULES & etc. |
  # --------------------------
  imports = with inputs; [
    home-manager.nixosModules.default
    disko.nixosModules.disko
    ../../modules/globals.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
    ./guests.nix
    ./modules
  ];

  # topology.self.hardware.image = ../../topology/images/Topton.webp;
  topology.self.hardware.info = "Intel N100, 16GB RAM";
  # |----------------------------------------------------------------------| #
  # | ADDITIONAL SYSTEM PACKAGES |
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    pkg-config
    pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
    usbutils # Tools for working with USB devices, such as lsusb
    minicom # Modem control and terminal emulation program
    inputs.power-meter.packages.${pkgs.system}.power-meter
  ];
  # |----------------------------------------------------------------------| #

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  # users.defaultUserShell = pkgs.nushell;
  users.defaultUserShell = pkgs.fish;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");
  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  # |----------------------------------------------------------------------| #
  systemd.tmpfiles.settings = {
    "10-var-lib-private" = {
      "/var/lib/private" = {
        d = {
          mode = "0700";
          user = "root";
          group = "root";
        };
      };
    };
  };
  # |----------------------------------------------------------------------| #
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

  security.pam.services = {
    swaylock = {};
  };
}
