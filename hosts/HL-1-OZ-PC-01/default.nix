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
    ./modules
  ];

  topology.self.icon = "devices.desktop";
  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    inputs.ibkr-rust.packages.${pkgs.system}.flex
    libva-utils
    networkmanagerapplet # need this to configure L2TP ipsec
    wireguard-tools
  ];

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

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

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
