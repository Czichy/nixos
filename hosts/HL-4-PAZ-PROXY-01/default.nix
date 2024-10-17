{
  pkgs,
  inputs,
  ...
}: let
  certloc = "/var/lib/acme/czichy.com";
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

  # topology.self.hardware.image = ../../topology/images/odroid-h3.png;
  topology.self.hardware.info = "NetCup VPS";
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

  # ---------------------
  # | ADDITIONAL CONFIG |
  # ---------------------
  services.qemuGuest.enable = true;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");

  # This node shall monitor the infrastructure
  # availableMonitoringNetworks = ["internet"];
  # };
}
