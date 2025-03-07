{
  pkgs,
  inputs,
  config,
  ...
}: let
  inherit (inputs.self) secretsPath;
in {
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

  users.defaultUserShell = pkgs.fish;
  # users.defaultUserShell = pkgs.nushell;

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

  programs.nix-ld.enable = true;

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };

  age.secrets = {
    dokumente = {
      symlink = true;
      file = secretsPath + "/resilio/dokumente.age";
      mode = "0600";
    };
    trading = {
      symlink = true;
      file = secretsPath + "/resilio/trading.age";
      mode = "0600";
    };
  };

  tensorfiles.services.resilio.enable = true;
  services.resilio = {
    # deviceName = "HL-1-OZ-PC-01";
    sharedFolders = [
      {
        secretFile = config.age.secrets.trading.path; # I want to make a mirror on the server, so the read-only key works perfectly
        directory = "/home/czichy/Trading";
        knownHosts = [];
        useRelayServer = true;
        useTracker = true;
        useDHT = true;
        searchLAN = true;
        useSyncTrash = true;
      }
      {
        secretFile = config.age.secrets.dokumente.path; # I want to make a mirror on the server, so the read-only key works perfectly
        directory = "/home/czichy/Dokumente";
        knownHosts = [];
        useRelayServer = true;
        useTracker = true;
        useDHT = true;
        searchLAN = true;
        useSyncTrash = true;
      }
    ];
  };
}
