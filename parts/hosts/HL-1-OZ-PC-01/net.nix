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
  # Enable NetworkManager
  # networking = {
  #   networkmanager.enable = true;
  #   useDHCP = false;
  #   interfaces.enp39s0 = {
  #     useDHCP = true;
  #     wakeOnLan.enable = true;

  #     ipv4 = {
  #       addresses = [
  #         {
  #           address = "192.168.1.62";
  #           prefixLength = 24;
  #         }
  #       ];
  #     };
  #   };
  # };

  networking = {
    useNetworkd = true;
    dhcpcd.enable = false;
    useDHCP = false;
    # allow mdns port
    firewall.allowedUDPPorts = [5353];
    # renameInterfacesByMac = lib.mkIf (!config.boot.isContainer) (
    #   lib.mapAttrs (_: v: v.mac) (config.secrets.secrets.local.networking.interfaces or {})
    # );
  };
  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;
  };
  services.resolved = {
    enable = true;
    # man I whish dnssec would be viable to use
    dnssec = "false";
    llmnr = "false";
    extraConfig = ''
      Domains=~.
      MulticastDNS=true
    '';
  };
  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  # boot.initrd.systemd.network = {
  #   enable = true;
  #   networks = {inherit (config.systemd.network.networks) "10-lan1";};
  # };
  boot.initrd.systemd.network = {
    enable = true;
    # netdevs = {
    #   "20-vlan10" = {
    #     netdevConfig = {
    #       Kind = "vlan";
    #       Name = "vlan10";
    #     };
    #     vlanConfig.Id = 10;
    #   };
    #   "20-vlan100" = {
    #     netdevConfig = {
    #       Kind = "vlan";
    #       Name = "vlan100";
    #     };
    #     vlanConfig.Id = 100;
    #   };
    # };
    networks = {
      "10-lan1" = {
        address = [
          globals.net.home-wan.hosts.HL-1-OZ-PC-01.cidrv4
          globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv4
        ];
        # gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
        # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
        matchConfig.MACAddress = macAddress_enp39s0;
        networkConfig.IPv6PrivacyExtensions = "yes";
        routes = [
          # create default routes for both IPv6 and IPv4
          # {routeConfig.Gateway = "fe80::1";}
          {Gateway = globals.net.home-wan.hosts.fritzbox.ipv4;}
          # or when the gateway is not on the same network
          # {
          #   routeConfig = {
          #     Gateway = "172.31.1.1";
          #     GatewayOnLink = true;
          #   };
          # }
        ];
        # make the routes on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
      # "40-lan1" = {
      #   address = [
      #     globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv4
      #     globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv6
      #   ];
      #   # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      #   matchConfig.MACAddress = macAddress_enp39s0;
      #   networkConfig = {
      #     IPv4Forwarding = "yes";
      #     IPv6PrivacyExtensions = "yes";
      #     MulticastDNS = true;
      #   };
      #   linkConfig.RequiredForOnline = "routable";
      # };
    };
  };
  systemd.network.networks = {
    "10-lan1" = {
      address = [
        globals.net.home-wan.hosts.HL-1-OZ-PC-01.cidrv4
        globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv4
        "192.168.0.62/24"
        "10.15.100.62/24"
      ];
      # gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      matchConfig.MACAddress = macAddress_enp39s0;
      networkConfig.IPv6PrivacyExtensions = "yes";
      routes = [
        # create default routes for both IPv6 and IPv4
        # {routeConfig.Gateway = "fe80::1";}
        {Gateway = globals.net.home-wan.hosts.fritzbox.ipv4;}
        # or when the gateway is not on the same network
        # {
        #   routeConfig = {
        #     Gateway = "172.31.1.1";
        #     GatewayOnLink = true;
        #   };
        # }
      ];
      # make the routes on this interface a dependency for network-online.target
      linkConfig.RequiredForOnline = "routable";
    };
    # "10-lan1" = {
    #   # DHCP = "yes";
    #   address = [
    #     globals.net.home-wan.hosts.HL-1-OZ-PC-01.cidrv4
    #   ];
    #   gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
    #   matchConfig.MACAddress = macAddress_enp39s0; # config.repo.secrets.local.networking.interfaces.lan1.mac;
    #   networkConfig = {
    #     IPv6PrivacyExtensions = "yes";
    #     MulticastDNS = true;
    #   };
    #   dhcpV4Config.RouteMetric = 10;
    #   dhcpV6Config.RouteMetric = 10;
    # };

    # "40-lan1" = {
    #   # DHCP = "yes";
    #   address = [
    #     globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv4
    #     # globals.net.vlan40.hosts.HL-1-OZ-PC-01.cidrv6
    #   ];
    #   matchConfig.MACAddress = macAddress_enp39s0; # config.repo.secrets.local.networking.interfaces.lan1.mac;
    #   networkConfig = {
    #     IPv6PrivacyExtensions = "yes";
    #     MulticastDNS = true;
    #   };
    #   dhcpV4Config.RouteMetric = 10;
    #   dhcpV6Config.RouteMetric = 10;
    # };
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
