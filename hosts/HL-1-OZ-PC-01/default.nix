{
  pkgs,
  inputs,
  ...
}: {
  # -----------------
  # | SPECIFICATION |
  # -----------------
  # Model: AMD Ryzen 9 9950X

  # --------------------------
  # | ROLES & MODULES & etc. |
  # --------------------------
  imports = with inputs; [
    hardware.nixosModules.common-cpu-amd
    hardware.nixosModules.common-gpu-amd
    # hardware.nixosModules.common-gpu
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
    openssl.dev
    openssl
    # inputs.ibkr-rust.packages.${pkgs.system}.flex
    libva-utils
    networkmanagerapplet # need this to configure L2TP ipsec
    wireguard-tools
    docker-compose
  ];
  virtualisation.podman.enable = true;
  users.users."czichy".extraGroups = ["docker"];

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  users.defaultUserShell = pkgs.fish;
  # users.defaultUserShell = pkgs.nushell;

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
    };
    # udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";
    # Needed for gpg pinetry
    # pcscd.enable = true;
  };

  programs.nix-ld.enable = true;

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  # users.users.qemu-libvirtd.group = "qemu-libvirtd";
  # users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
