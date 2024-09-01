{
  config,
  globals,
  lib,
  pkgs,
  ...
}: let
  adguardhomeDomain = "unifi.czichy.com";
  # adguardhomeDomain = "adguardhome.${config.repo.secrets.global.domains.me}";
  allowedRules = {
    # https://help.ui.com/hc/en-us/articles/218506997-UniFi-Ports-Used
    allowedTCPPorts = [
      8080 # Port for UAP to inform controller.
      8880 # Port used for HTTP portal redirection.
      8843 # Port used for HTTPS portal redirection.
      8443 # Port used for application GUI/API as seen in a web browser.
      6789 # Port for UniFi mobile speed test.
    ];
    allowedUDPPorts = [
      3478 # UDP port used for STUN.
      1900 # Port used for "Make application discoverable on L2 network" in the UniFi Network settings.
      10001 # Port used for device discovery.
    ];
  };
  # allowedInterfaces = [
  #   "enp57s0u1u3" # sighx2.1
  # ];
in {
  # wireguard.proxy-sentinel = {
  #   client.via = "sentinel";
  #   firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.adguardhome.port];
  # };
  globals.services.unifi.domain = adguardhomeDomain;
  # globals.monitoring.dns.adguardhome = {
  #   server = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
  #   domain = ".";
  #   network = "home-lan";
  # };
  # systemd.network.networks."20-tap" = {
  #   matchConfig.Type = "ether";
  #   matchConfig.MACAddress = "60:be:b4:19:a8:4f";
  #   networkConfig = {
  #     Address = ["10.15.1.40/24"];
  #     Gateway = "10.15.1.99";
  #     DNS = ["8.8.8.8"];
  #     IPv6AcceptRA = true;
  #     DHCP = "yes";
  #   };
  # };
  # nodes.sentinel = {
  #   services.nginx = {
  #     upstreams.adguardhome = {
  #       # servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.adguardhome.port}" = {};
  #       extraConfig = ''
  #         zone adguardhome 64k;
  #         keepalive 2;
  #       '';
  #       monitoring = {
  #         enable = true;
  #         expectedBodyRegex = "AdGuard Home";
  #       };
  #     };
  #     virtualHosts.${adguardhomeDomain} = {
  #       forceSSL = true;
  #       useACMEWildcardHost = true;
  #       oauth2.enable = true;
  #       oauth2.allowedGroups = ["access_adguardhome"];
  #       locations."/" = {
  #         proxyPass = "http://adguardhome";
  #         proxyWebsockets = true;
  #       };
  #     };
  #   };
  # };

  # environment.persistence."/persist".directories = [
  #   {
  #     directory = "/var/lib/private/AdGuardHome";
  #     mode = "0700";
  #   }
  # ];

  networking.firewall = {
    allowedTCPPorts = allowedRules.allowedTCPPorts;
    allowedUDPPorts = allowedRules.allowedUDPPorts;
  };

  services.unifi = {
    enable = true;
    openFirewall = false;
    unifiPackage = pkgs.unifi6;
    jrePackage = pkgs.jdk8_headless;
    # mongodbPackage = pkgs.mongodb-3_4;
    maximumJavaHeapSize = 256;
  };
  systemd.network.enable = true;
  networking.hostName = "HL-1-MRZ-SBC-01-unifi";
  # systemd.network.networks."99-v-lan" = {
  #   matchConfig.Type = "ether";
  #   DHCP = "yes";
  #   networkConfig = {
  #     Address = [globals.net.vlan40.hosts.HL-1-MRZ-SBC-01-adguardhome.ipv4];
  #     # Gateway = [globals.net.vlan40.cidrv4];
  #     # DNS = nameservers;
  #   };
  # };
  system.stateVersion = "24.05";
}
