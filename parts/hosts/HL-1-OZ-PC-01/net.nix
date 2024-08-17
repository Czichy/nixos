{
  config,
  globals,
  ...
}: let
  macAddress_enp39s0 = "2c:f0:5d:9f:10:37";
in {
  # networking = {
  #   inherit (config.repo.secrets.local.networking) hostId;
  # };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-lan1";};
  };

  systemd.network.networks = {
    "10-lan1" = {
      # DHCP = "yes";
      address = [
        globals.net.home-wan.hosts.HL-1-OZ-PC-01.cidrv4
      ];
      matchConfig.MACAddress = macAddress_enp39s0; # config.repo.secrets.local.networking.interfaces.lan1.mac;
      networkConfig = {
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };

    "40-lan1" = {
      # DHCP = "yes";
      address = [
        globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv4
        globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv6
      ];
      matchConfig.MACAddress = macAddress_enp39s0; # config.repo.secrets.local.networking.interfaces.lan1.mac;
      networkConfig = {
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      dhcpV4Config.RouteMetric = 10;
      dhcpV6Config.RouteMetric = 10;
    };
    # "10-wlan1" = {
    #   DHCP = "yes";
    #   matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wlan1.mac;
    #   networkConfig = {
    #     IPv6PrivacyExtensions = "yes";
    #     MulticastDNS = true;
    #   };
    #   dhcpV4Config.RouteMetric = 40;
    #   dhcpV6Config.RouteMetric = 40;
    # };
  };

  # networking.nftables.firewall = {
  #   zones.untrusted.interfaces = ["lan1" "wlan1"];
  # };
}
