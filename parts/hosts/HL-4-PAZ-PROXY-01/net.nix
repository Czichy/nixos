{
  config,
  lib,
  globals,
  ...
}
: {
  # networking.hostId = config.repo.secrets.local.networking.hostId;

  globals.monitoring.ping.ward = {
    hostv4 = "127.0.0.1";
    network = "home-lan";
  };

  # Enable NetworkManager
  networking = {
    networkmanager.enable = true;
    hostName = "home_server_test";
    useDHCP = false;
    interfaces.enp1s0 = {
      useDHCP = true;
      wakeOnLan.enable = true;

      ipv4 = {
        addresses = [
          {
            # "192.168.122.175"
            address = "${globals.net.v-lan.hosts.ward.ipv4}";
            prefixLength = 24;
          }
          {
            address = "192.168.122.75";
            prefixLength = 24;
          }
        ];
      };
    };
  };

  boot.initrd.systemd.network = {
    # enable = true;
    networks = {
      inherit (config.systemd.network.networks) "10-wan";
      "20-lan" = {
        address = [
          {
            addressConfig.Address = "fd12:3456:789a::1/64";
          }
          # {
          #   # "192.168.122.175"
          #   address = "${globals.net.v-lan.hosts.ward.ipv4}";
          #   prefixLength = 24;
          # }
          globals.net.home-lan.hosts.ward.cidrv4
          globals.net.home-lan.hosts.ward.cidrv6
        ];
        # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
        networkConfig = {
          IPForward = "yes";
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
      address = [globals.net.home-wan.hosts.ward.cidrv4];
      gateway = [globals.net.home-wan.hosts.fritzbox.ipv4];
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
    "20-lan-self" = {
      address = [
        globals.net.home-lan.hosts.ward.cidrv4
        globals.net.home-lan.hosts.ward.cidrv6
      ];
      matchConfig.Name = "lan-self";
      networkConfig = {
        IPForward = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPPrefixDelegation = true;
        MulticastDNS = true;
      };
      # Announce a static prefix
      ipv6Prefixes = [
        {ipv6PrefixConfig.Prefix = globals.net.home-lan.cidrv6;}
      ];
      # Delegate prefix
      dhcpPrefixDelegationConfig = {
        SubnetId = "22";
      };
      # Provide a DNS resolver
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
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
  #   host = globals.net.home-lan.hosts.ward.ipv4;
  #   port = 51444;
  #   reservedAddresses = [
  #     globals.net.proxy-home.cidrv4
  #     globals.net.proxy-home.cidrv6
  #   ];
  #   openFirewall = false; # Explicitly opened only for lan
  # };
}