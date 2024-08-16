{
  config,
  lib,
  globals,
  ...
}
: let
  macAddress_enp1s0 = "60:be:b4:19:a8:4c";
  macAddress_enp2s0 = "60:be:b4:19:a8:4d";
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

  # Enable NetworkManager
  # networking = {
  #   networkmanager.enable = true;
  #   interfaces.enp2s0 = {
  #     ipv4 = {
  #       addresses = [
  #         # {
  #         #   address = "${globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.ipv4}";
  #         #   prefixLength = 24;
  #         # }
  #         {
  #           address = "192.168.1.254";
  #           prefixLength = 24;
  #         }
  #       ];
  #     };
  #   };
  # };

  boot.initrd.systemd.network = {
    enable = true;
    networks = {
      "10-wan" = {
        address = [globals.net.home-wan.hosts.HL-1-MRZ-SBC-01.cidrv4];
        gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
        # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
        matchConfig.MACAddress = macAddress_enp1s0;
        networkConfig.IPv6PrivacyExtensions = "yes";
        linkConfig.RequiredForOnline = "routable";
      };
      "20-lan" = {
        address = [
          # {
          #   addressConfig.Address = "fd12:3456:789a::1/64";
          # }
          globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4
          globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6
        ];
        # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
        matchConfig.MACAddress = macAddress_enp2s0;
        networkConfig = {
          IPv4Forwarding = "yes";
          IPv6PrivacyExtensions = "yes";
          MulticastDNS = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Create a MACVTAP for ourselves too, so that we can communicate with
  # our guests on the same interface.
  systemd.network.netdevs."10-lan-self" = {
    netdevConfig = {
      Name = "lan-self";
      Kind = "macvlan";
    };
    extraConfig = ''
      [MACVLAN]
      Mode=bridge
    '';
  };

  systemd.network.networks = {
    "10-lan" = {
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      matchConfig.MACAddress = macAddress_enp2s0;
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVLAN=lan-self
      '';
    };
    "10-wan" = {
      #DHCP = "yes";
      #dhcpV4Config.UseDNS = false;
      #dhcpV6Config.UseDNS = false;
      #ipv6AcceptRAConfig.UseDNS = false;
      address = [globals.net.home-wan.hosts.HL-1-MRZ-SBC-01.cidrv4];
      gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      matchConfig.MACAddress = macAddress_enp1s0;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
    "20-lan-self" = {
      address = [
        globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv4
        globals.net.vlan40.hosts.HL-1-MRZ-SBC-01.cidrv6
      ];
      matchConfig.Name = "lan-self";
      networkConfig = {
        IPv4Forwarding = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPPrefixDelegation = true;
        MulticastDNS = true;
      };
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = globals.net.vlan40.cidrv6;}
      ];
      # Delegate prefix
      dhcpPrefixDelegationConfig = {
        SubnetId = "22";
      };
      # Provide a DNS resolver
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = globals.net.vlan40.hosts.HL-1-MRZ-SBC-01-adguardhome.ipv4;
      };
      linkConfig.RequiredForOnline = "routable";
    };
    # Remaining macvtap interfaces should not be touched.
    "90-macvtap-ignore" = {
      matchConfig.Kind = "macvtap";
      linkConfig.ActivationPolicy = "manual";
      linkConfig.Unmanaged = "yes";
    };
  };

  networking.nftables.firewall = {
    snippets.nnf-icmp.ipv6Types = ["mld-listener-query" "nd-router-solicit"];

    zones = {
      untrusted.interfaces = ["wan"];
      lan.interfaces = ["lan-self"];
      proxy-home.interfaces = ["proxy-home"];
    };

    rules = {
      masquerade = {
        from = ["lan"];
        to = ["untrusted"];
        masquerade = true;
      };

      outbound = {
        from = ["lan"];
        to = ["lan" "untrusted"];
        late = true; # Only accept after any rejects have been processed
        verdict = "accept";
      };

      lan-to-local = {
        from = ["lan"];
        to = ["local"];

        allowedUDPPorts = [51444];
        # allowedUDPPorts = [config.wireguard.proxy-home.server.port];
      };

      # Forward traffic between participants
      forward-proxy-home-vpn-traffic = {
        from = ["proxy-home"];
        to = ["proxy-home"];
        verdict = "accept";
      };
    };
  };

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
