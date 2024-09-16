{
  config,
  lib,
  globals,
  ...
}
: let
  # macAddress_enp1s0 = "60:be:b4:19:a8:4c";
  macAddress_enp4s0 = "60:be:b4:19:a8:4f";
in {
  # networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.HL-1-MRZ-SBC-01 = {
    hostv4 = lib.net.cidr.ip globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6;
    network = "vlan40";
  };
  networking = {
    useNetworkd = true;
    dhcpcd.enable = false;
    useDHCP = false;
    # allow mdns port
    firewall.allowedUDPPorts = [5353];
    # firewall.allowedTCPPorts = [3000 80 53 443];
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
    # Disable local DNS stub listener on 127.0.0.53
    fallbackDns = [
      "1.1.1.1"
      "2606:4700:4700::1111"
      "8.8.8.8"
      "2001:4860:4860::8844"
    ];
    extraConfig = ''
      Domains=~.
      MulticastDNS=true
      DNSStubListener=no
    '';
  };

  # boot.initrd.systemd.network = {
  #   enable = true;
  #   networks = {
  #     # "10-wan" = {
  #     #   address = [globals.net.home-wan.hosts.HL-1-MRZ-SBC-01.cidrv4];
  #     #   gateway = [globals.net.home-wan.hosts.opnsense.ipv4];
  #     #   # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
  #     #   matchConfig.MACAddress = macAddress_enp1s0;
  #     #   networkConfig.IPv6PrivacyExtensions = "yes";
  #     #   linkConfig.RequiredForOnline = "routable";
  #     # };
  #     "20-lan40" = {
  #       address = [
  #         # {
  #         #   addressConfig.Address = "fd12:3456:789a::1/64";
  #         # }
  #         globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4
  #         globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6
  #       ];
  #       gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
  #       # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
  #       matchConfig.MACAddress = macAddress_enp4s0;
  #       networkConfig = {
  #         IPv4Forwarding = "yes";
  #         IPv6PrivacyExtensions = "yes";
  #         MulticastDNS = true;
  #       };
  #       linkConfig.RequiredForOnline = "routable";
  #     };
  #   };
  # };

  # |----------------------------------------------------------------------| #
  # Create a MACVTAP for ourselves too, so that we can communicate with
  # our guests on the same interface.
  systemd.network.netdevs."10-lan-self" = {
    netdevConfig = {
      Name = "lan-self";
      Kind = "macvlan";
    };
    vlanConfig.Id = 40;
    extraConfig = ''
      [MACVLAN]
      Mode=bridge
    '';
  };
  systemd.network.netdevs."10-servers" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "servers";
      Description = "Servers VLAN40 RZ";
    };
    vlanConfig.Id = 40;
  };
  # systemd.network.netdevs."10-br40" = {
  #   netdevConfig.Kind = "bridge";
  #   netdevConfig.Name = "br40";
  # };

  systemd.network.netdevs."10-mgmt" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "mgmt";
      Description = "Management VLAN100 MRZ";
    };
    vlanConfig.Id = 100;
  };

  # |----------------------------------------------------------------------| #
  systemd.network.networks = {
    # "20-lan" = {
    #   matchConfig.MACAddress = macAddress_enp4s0;
    #   # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
    #   # This interface should only be used from attached macvtaps.
    #   # So don't acquire a link local address and only wait for
    #   # this interface to gain a carrier.
    #   networkConfig.LinkLocalAddressing = "no";
    #   linkConfig.RequiredForOnline = "carrier";
    #   extraConfig = ''
    #     [Network]
    #     MACVLAN=lan-self
    #   '';
    # };
    "30-lan" = {
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      matchConfig.MACAddress = macAddress_enp4s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      address = [
        "10.15.40.154/24"
        "10.15.1.42/24"
      ];
      # gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      routes = [{Gateway = "10.15.1.99";}];
      vlan = [
        "servers"
        "mgmt"
      ];
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVLAN=lan-self
      '';
    };
    "30-servers" = {
      # matchConfig.Name = ["servers" "lan-self"];
      matchConfig.Name = "servers";
      matchConfig.Type = "vlan";
      # address = [
      # globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4
      # globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6
      # ];
      gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
      # address = ["10.15.40.20/24"];
      # gateway = ["10.15.40.99"];
      # networkConfig.Bridge = "br20";
      # networkConfig = {
      #   ConfigureWithoutCarrier = true;
      #   DHCP = "yes";
      # };
      linkConfig.RequiredForOnline = "routable";
    };

    # "30-vm40-bridge" = {
    #   matchConfig.Name = ["servers" "vm-40-*"];
    #   networkConfig.Bridge = "br20";
    #   networkConfig.DHCP = "no";
    #   networkConfig.LinkLocalAddressing = "no";
    #   networkConfig.IPv6PrivacyExtensions = "kernel";
    # };

    # "20-br40" = {
    #   matchConfig.Name = "br40";
    #   networkConfig.DHCP = "no";
    #   networkConfig.LinkLocalAddressing = "no";
    #   networkConfig.IPv6PrivacyExtensions = "kernel";
    # };
    # "10-wan" = {
    #   #DHCP = "yes";
    #   #dhcpV4Config.UseDNS = false;
    #   #dhcpV6Config.UseDNS = false;
    #   #ipv6AcceptRAConfig.UseDNS = false;
    #   address = [globals.net.home-wan.hosts.HL-1-MRZ-SBC-01.cidrv4];
    #   gateway = [globals.net.home-wan.hosts.opnsense.ipv4];
    #   # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
    #   matchConfig.MACAddress = macAddress_enp1s0;
    #   networkConfig.IPv6PrivacyExtensions = "yes";
    #   linkConfig.RequiredForOnline = "routable";
    # };
    "30-mgmt" = {
      matchConfig.Name = "mgmt";
      matchConfig.Type = "vlan";
      bridgeConfig = {};
      address = [
        globals.net.vlan100.hosts.HL-1-MRZ-SBC-01.cidrv4
        # globals.net.vlan100.hosts.HL-1-MRZ-SBC-01.cidrv6
      ];
      gateway = [globals.net.vlan100.hosts.opnsense.ipv4];
      # address = ["10.15.100.20/24"];
      # gateway = ["10.15.100.99"];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "30-lan-self" = {
      matchConfig.Name = "lan-self";
      # address = [
      # "10.15.40.177/24"
      # globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4
      # globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6
      # ];
      # gateway = [globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.ipv4];
      gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
      # vlan = [
      #   "servers"
      #   # "mgmt"
      # ];
      networkConfig = {
        IPv4Forwarding = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPPrefixDelegation = true;
        MulticastDNS = true;
      };
      # dhcpPrefixDelegationConfig.UplinkInterface = "wan";
      dhcpPrefixDelegationConfig.Token = "::ff";
      # Announce a static prefix
      # ipv6Prefixes = [
      #   {Prefix = globals.net.home-lan.cidrv6;}
      # ];
      # Delegate prefix
      # dhcpPrefixDelegationConfig = {
      #   SubnetId = "22";
      # };
      # # Announce a static prefix
      # ipv6Prefixes = [
      #   {ipv6PrefixConfig.Prefix = globals.net.vlan40.cidrv6;}
      # ];
      # # Delegate prefix
      # dhcpPrefixDelegationConfig = {
      #   SubnetId = "22";
      # };
      # # Provide a DNS resolver
      # ipv6SendRAConfig = {
      #   EmitDNS = true;
      #   DNS = globals.net.vlan40.hosts.HL-1-MRZ-SBC-01-adguardhome.ipv4;
      # };
      linkConfig.RequiredForOnline = "routable";
    };

    # Remaining macvtap interfaces should not be touched.
    "90-macvtap-ignore" = {
      matchConfig.Kind = "macvtap";
      linkConfig.ActivationPolicy = "manual";
      linkConfig.Unmanaged = "yes";
    };
  };

  # networking.nftables.firewall = {
  #   snippets.nnf-icmp.ipv6Types = ["mld-listener-query" "nd-router-solicit"];

  #   zones = {
  #     untrusted.interfaces = ["wan"];
  #     lan.interfaces = ["lan-self"];
  #     proxy-home.interfaces = ["proxy-home"];
  #   };

  #   rules = {
  #     masquerade = {
  #       from = ["lan"];
  #       to = ["untrusted"];
  #       masquerade = true;
  #     };

  #     outbound = {
  #       from = ["lan"];
  #       to = ["lan" "untrusted"];
  #       late = true; # Only accept after any rejects have been processed
  #       verdict = "accept";
  #     };

  #     lan-to-local = {
  #       from = ["lan"];
  #       to = ["local"];

  #       allowedUDPPorts = [51444];
  #       # allowedUDPPorts = [config.wireguard.proxy-home.server.port];
  #     };

  #     # Forward traffic between participants
  #     forward-proxy-home-vpn-traffic = {
  #       from = ["proxy-home"];
  #       to = ["proxy-home"];
  #       verdict = "accept";
  #     };
  #   };
  # };

  # tensorfiles.services.networking.wireguard.enable = true;
  # tensorfiles.services.networking.wireguard.proxy-home.server = {
  #   host = globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.ipv4;
  #   port = 51444;
  #   reservedAddresses = [
  #     globals.net.proxy-home.cidrv4
  #     globals.net.proxy-home.cidrv6
  #   ];
  #   openFirewall = false; # Explicitly opened only for lan
  # };
}
