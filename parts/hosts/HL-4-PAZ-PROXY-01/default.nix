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
    home-manager.nixosModules.default
    disko.nixosModules.disko
    ../../../globals/globals.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
    ./acme.nix
  ];

  # topology.self.hardware.image = ../../topology/images/odroid-h3.png;
  topology.self.hardware.info = "O-Droid H3, 64GB RAM";
  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    networkmanagerapplet # need this to configure L2TP ipsec
    wireguard-tools
  ];

  wireguard.proxy-sentinel.firewallRuleForAll.allowedTCPPorts = [80 443];

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;

  # services.nginx.virtualHosts.${globals.domains.me} = {
  #   forceSSL = true;
  #   useACMEWildcardHost = true;
  #   locations."/".root = pkgs.runCommand "index.html" {} ''
  #     mkdir -p $out
  #     cat > $out/index.html <<EOF
  #     <html>
  #       <body>Not empty soon TM. Until then please go here: <a href="https://github.com/oddlama">oddlama</a></body>
  #     </html>
  #     EOF
  #   '';
  # };

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
        rootPartition = "/dev/vda2";
      };
    };
    security.agenix.enable = false;

    system.users.usersSettings."root" = {
      agenixPassword.enable = false;
    };
    system.users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      agenixPassword.enable = false;
      extraGroups = [
        "networkmanager"
        "input"
        "docker"
      ];
    };
  };

  users.defaultUserShell = pkgs.nushell;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");

  # Connect safely via wireguard to skip authentication
  # networking.hosts.${config.wireguard.proxy-sentinel.ipv4} = [globals.services.influxdb.domain];
  # meta.telegraf = {
  #   enable = true;
  #   scrapeSensors = false;
  #   influxdb2 = {
  #     inherit (globals.services.influxdb) domain;
  #     organization = "machines";
  #     bucket = "telegraf";
  #     node = "sire-influxdb";
  #   };

  #   # This node shall monitor the infrastructure
  #   availableMonitoringNetworks = ["internet"];
  # };
}
