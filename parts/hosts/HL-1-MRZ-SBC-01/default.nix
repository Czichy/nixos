# --- parts/hosts/spinorbundle/default.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{
  pkgs,
  secretsPath,
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
    ../../../globals/globals.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
    ./guests.nix
  ];

  # topology.self.hardware.image = ../../topology/images/Topton.webp;
  topology.self.hardware.info = "Topton, 16GB RAM";
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
  tensorfiles = {
    profiles.server.enable = true;
    profiles.packages-extra.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
      btrfsWipe = {
        enable = false;
        rootPartition = "/dev/nvme0n1";
      };
    };
    services = {
      virtualisation.enable = true;
    };
    security.agenix.enable = true;

    system.users.usersSettings."root" = {
      uid = 0;
      gid = 0;
      agenixPassword.enable = true;
    };
    system.users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      uid = 1000;
      gid = 1000;
      agenixPassword.enable = true;
      extraGroups = [
        "networkmanager"
        "input"
        "docker"
        "kvm"
        "libvirt"
        "libvirtd"
        "network"
        "podman"
        "qemu-libvirtd"
      ];
    };
  };

  users.defaultUserShell = pkgs.nushell;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");
  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
