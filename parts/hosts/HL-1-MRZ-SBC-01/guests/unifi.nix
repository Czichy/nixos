{
  config,
  globals,
  lib,
  pkgs,
  ...
}: let
  unifiDomain = "unifi.czichy.com";
  # adguardhomeDomain = "adguardhome.${config.repo.secrets.global.domains.me}";
in {
  # wireguard.proxy-sentinel = {
  #   client.via = "sentinel";
  #   firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.adguardhome.port];
  # };

  globals.services.unifi.domain = unifiDomain;
  # globals.monitoring.dns.adguardhome = {
  #   server = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
  #   domain = ".";
  #   network = "home-lan";
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

  # networking.firewall = {
  #   allowedTCPPorts = [53 80 443 3000];
  #   allowedUDPPorts = [53];
  # };

  # topology.self.services.adguardhome.info = "https://" + adguardhomeDomain;
  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi8;
    openFirewall = true;
    mongodbPackage = pkgs.hello; # use ferretdb instead
  };
  services.ferretdb = {
    enable = true;
    package = pkgs.unstable.ferretdb;
  };

  # systemd.services.adguardhome = {
  #   preStart = lib.mkAfter ''
  #     INTERFACE_ADDR=$(${pkgs.iproute2}/bin/ip -family inet -brief addr show lan | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+") \
  #       ${lib.getExe pkgs.yq-go} -i '.dns.bind_hosts = [strenv(INTERFACE_ADDR)]' \
  #       "$STATE_DIRECTORY/AdGuardHome.yaml"
  #   '';
  #   serviceConfig.RestartSec = lib.mkForce "60"; # Retry every minute
  # };

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
