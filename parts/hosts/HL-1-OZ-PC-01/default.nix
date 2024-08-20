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
    hardware.nixosModules.common-cpu-amd
    hardware.nixosModules.common-gpu-amd
    hardware.nixosModules.common-pc-ssd
    home-manager.nixosModules.default
    disko.nixosModules.disko
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
  ];

  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    libva-utils
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
    profiles.packages-extra.enable = true;
    profiles.graphical-hyprland.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
    };
    security.agenix.enable = true;

    system.users.usersSettings."root" = {
      agenixPassword.enable = true;
    };
    system.users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      agenixPassword.enable = true;
      extraGroups = [
        "video"
        "audio"
        "networkmanager"
        "input"
        # ]
        # ++ ifTheyExist [
        "camera"
        "deluge"
        "docker"
        "git"
        "i2c"
        "kvm"
        "libvirt"
        "libvirtd"
        "network"
        "nitrokey"
        "podman"
        "qemu-libvirtd"
        "wireshark"
        "flatpak"
      ];
    };
    services = {
      flatpak.enable = true;
      printing.enable = true;
      syncthing = {
        enable = true;
        user = "czichy";
      };
      virtualisation.enable = true;
    };
  };

  users.defaultUserShell = pkgs.nushell;

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
    udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";
    # Needed for gpg pinetry
    # pcscd.enable = true;
  };

  # FIXME: the ui is not directly accessible via environment.systemPackages
  # FIXME: to control it as a user (and to allow SSO) we need to be in the netbird-home group
  # services.netbird.ui.enable = true;
  # services.netbird.clients.home = {
  #   port = 51820;
  #   name = "netbird-home";
  #   interface = "wt-home";
  #   autoStart = false;
  #   openFirewall = true;
  #   config.ServerSSHAllowed = false;
  #   environment = rec {
  #     NB_MANAGEMENT_URL = "https://${globals.services.netbird.domain}";
  #     NB_ADMIN_URL = NB_MANAGEMENT_URL;
  #   };
  # };
  # environment.persistence."/persist".directories = [
  #   {
  #     directory = "/var/lib/netbird-home";
  #     mode = "0700";
  #   }
  # ];

  programs.nix-ld.enable = true;
  topology.self.icon = "devices.desktop";

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
