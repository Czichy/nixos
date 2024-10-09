{
  config,
  globals,
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
  # services.nginx = {
  #   enable = true;
  #   recommendedSetup = true;

  #   virtualHosts.${globals.domains.me} = {
  #     forceSSL = true;
  #     useACMEWildcardHost = true;
  #     locations."/".root = pkgs.runCommand "index.html" {} ''
  #       mkdir -p $out
  #       cat > $out/index.html <<EOF
  #       <html>
  #         <body>Not empty soon TM. Until then please go here: <a href="https://github.com/oddlama">oddlama</a></body>
  #       </html>
  #       EOF
  #     '';
  #   };
  # };

  # # SSL config and forwarding to local reverse proxy
  # services.caddy.enable = true;
  #  = {
  #   virtualHosts."adguardhome.czichy.com".extraConfig = ''
  #     reverse_proxy 10.15.70.1

  #       tls ${certloc}/cert.pem ${certloc}/key.pem {
  #         protocols tls1.3
  #       }
  #   '';
  # };

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");

  # Connect safely via wireguard to skip authentication
  # networking.hosts.${config.wireguard.proxy-public.ipv4} = [globals.services.influxdb.domain];
  # meta.telegraf = {
  #   enable = true;
  #   scrapeSensors = false;
  #   influxdb2 = {
  #     inherit (globals.services.influxdb) domain;
  #     organization = "machines";
  #     bucket = "telegraf";
  #     node = "sire-influxdb";
  #   };

  # This node shall monitor the infrastructure
  # availableMonitoringNetworks = ["internet"];
  # };
}
