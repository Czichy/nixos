{
  pkgs,
  inputs,
  lib,
  secretsPath,
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

  # users.defaultUserShell = pkgs.fish;
  users.defaultUserShell = lib.mkForce pkgs.nushell;
  users.users."czichy".shell = lib.mkForce pkgs.nushell;

  services = {
    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;
      # Fix HECATE G1000 II: broken PCM dB range causes audio dropouts.
      # WirePlumber rule to use linear volume control instead of dB.
      wireplumber.extraConfig."51-hecate-g1000" = {
        "monitor.alsa.rules" = [
          {
            matches = [{"node.name" = "alsa_output.usb-_HECATE_G1000_II-00.analog-stereo";}];
            actions.update-props = {
              "api.alsa.soft-mixer" = true;
              "node.pause-on-idle" = false;
            };
          }
        ];
      };
    };
    # udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";
    # Needed for gpg pinetry
    # pcscd.enable = true;
  };

  # HECATE G1000 II (USB VID:35bb PID:b0c8): disable USB autosuspend to
  # prevent audio dropouts when device briefly suspends between sounds.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="35bb", ATTRS{idProduct}=="b0c8", TEST=="power/control", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
  '';

  programs.nix-ld.enable = true;

  # Steam needs system-level integration for sandbox setuid wrappers,
  # firewall rules, and proper FHS environment (fixes launch from Walker/desktop)
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = with pkgs; [
      libxcursor
      libxi
      libxinerama
      libxscrnsaver
      libpng
      libpulseaudio
      libvorbis
      stdenv.cc.cc.lib
      libkrb5
      keyutils
      gamescope
      mangohud
    ];
  };

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  # users.users.qemu-libvirtd.group = "qemu-libvirtd";
  # users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
