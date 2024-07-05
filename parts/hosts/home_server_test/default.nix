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
  system,
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
    disko.nixosModules.disko
    ./hardware-configuration.nix
    ./disko.nix
    # ./microvm
  ];

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
    profiles.graphical-startx-home-manager.enable = true;
    profiles.packages-extra.enable = true;

    system.impermanence = {
      enable = true;
      allowOther = true;
      btrfsWipe = {
        enable = true;
        rootPartition = "/dev/vda2";
      };
    };
    security.agenix.enable = true;

    services.virtualisation.microvm = {
      enable = true;
      test.enable = true;
    };

    # services.printing.enable = true;
    # services.syncthing = {
    #   enable = true;
    #   user = "czichy";
    # };

    system.users.usersSettings."root" = {
      agenixPassword.enable = true;
    };
    system.users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      agenixPassword.enable = true;
      extraGroups = [
        "video"
        "camera"
        "audio"
        "networkmanager"
        "input"
        "docker"
      ];
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
  };

  # Enable NetworkManager
  networking = {
    networkmanager.enable = true;
    hostName = "vm_test";
    useDHCP = false;
    interfaces.enp1s0 = {
      useDHCP = true;
      wakeOnLan.enable = true;

      ipv4 = {
        addresses = [
          {
            address = "192.168.122.198";
            prefixLength = 24;
          }
        ];
      };
    };
  };
  #networking.networkmanager.enableStrongSwan = true;
  #services.xl2tpd.enable = true;
  #services.strongswan = {
  #  enable = true;
  #  secrets = [ "ipsec.d/ipsec.nm-l2tp.secrets" ];
  #};

  #virtualisation.docker = {
  #  enable = true;
  #  autoPrune.enable = true;
  #  storageDriver = "btrfs";
  #};

  # NOTE for wireguard
  networking.wireguard.enable = true;
  networking.firewall = {
    allowedUDPPorts = [51820];
  };

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = {
    tensorfiles.hm = {
      security.agenix.enable = true;

      system.impermanence = {
        enable = true;
        allowOther = true;
      };
      programs = {
        ssh = {
          enable = true;
          sshKey.enable = false;
        };
      };
      hardware.monitors = {
        enable = true;
        monitors = [
          {
            name = "Virtual-1";
            width = 2560;
            height = 1600;
            hasBar = true;
            refreshRate = 75;
            x = 0;
            workspace = "1";
            primary = true;
          }
        ];
      };
    };

    home.username = "czichy";
    home.homeDirectory = "/home/czichy";
    home.sessionVariables = {
      DEFAULT_USERNAME = "czichy";
      DEFAULT_MAIL = "christian@czichy.com";
    };
  };
}
