{
  pkgs,
  inputs,
  config,
  ...
}: let
  inherit
    (config.lib.topology)
    # mkDevice
    
    mkConnection
    ;
in {
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
    ./modules
  ];

  topology.self = {
    hardware.info = "OPNSense";
    # hardware.image = ../../topology/images/Topton.webp;
    # guestType = "qemu";
    deviceIcon = "services.opnsense";
    parent = "HL-1-MRZ-SBC-01";
    guestType = "qemu";
    interfaces.wan = {
      # addresses = ["10.15.1.99"];
      network = "internet";
      physicalConnections = [(mkConnection "vigor" "p1")];
    };
    interfaces = {
      lan = {
        addresses = ["10.15.1.99"];
        network = "lan";
        physicalConnections = [(mkConnection "switch-keller" "eth16")];
      };
      trust = {
        network = "trust";
        addresses = ["10.15.10.99/24"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-keller" "eth16")];
      };
      mgmt = {
        network = "mgmt";
        addresses = ["10.15.100.99/24"];
        virtual = true;
        physicalConnections = [(mkConnection "switch-keller" "eth16")];
      };
    };
  };
  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    networkmanagerapplet # need this to configure L2TP ipsec
    wireguard-tools
  ];

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  users.defaultUserShell = pkgs.nushell;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  # home-manager.users."czichy" = import (../../homes + "/czichy@server");
  # users.users.qemu-libvirtd.group = "qemu-libvirtd";
  # users.groups.qemu-libvirtd = {};

  # security.pam.services = {
  #   swaylock = {};
  # };
}
