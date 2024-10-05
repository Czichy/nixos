{
  globals,
  inputs,
  config,
  ...
}: let
  inherit (inputs.self) lib;
  inherit (inputs.self) secretsPath;

  wgName = "proxy-vps";
  inherit
    (lib.wireguard inputs wgName)
    peerPublicKeyPath
    peerPrivateKeyPath
    peerPresharedKeyPath
    ;

  nodeName = config.node.name;
  opnsense = "HL-1-MRZ-SBC-01-opnsense";
  # config.repo.secrets.local = {
  local = {
    networking = {
      interfaces = {
        wan = {
          hostCidrv4 = "37.120.178.230/22";
          hostCidrv6 = "2a03:4000:6:8128::/64";
          mac = "da:22:45:bf:e9:98";
          gateway = {
            cidrv4 = "37.120.176.1";
            cidrv6 = "fe80::1";
          };
        };
      };
    };
  };
  icfg = local.networking.interfaces.wan;
  # icfg = config.repo.secrets.local.networking.interfaces.wan;
in {
  # networking.hostId = config.repo.secrets.local.networking.hostId;
  networking.domain = globals.domains.me;

  globals.monitoring.ping.sentinel = {
    hostv4 = lib.net.cidr.ip icfg.hostCidrv4;
    hostv6 = lib.net.cidr.ip icfg.hostCidrv6;
    network = "internet";
  };

  # Forwarding required for forgejo 9922->22
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  boot.initrd.systemd.network = {
    enable = true;
    networks = {inherit (config.systemd.network.networks) "10-wan";};
  };

  # networking = {
  #   useNetworkd = true;
  #   dhcpcd.enable = false;
  #   useDHCP = false;
  #   # allow mdns port
  #   firewall.allowedUDPPorts = [5353];
  #   # firewall.allowedTCPPorts = [3000 80 53 443];
  #   # renameInterfacesByMac = lib.mkIf (!config.boot.isContainer) (
  #   #   lib.mapAttrs (_: v: v.mac) (config.secrets.secrets.local.networking.interfaces or {})
  #   # );
  # };
  # systemd.network = {
  #   enable = true;
  #   wait-online.anyInterface = true;
  # };
  # services.resolved = {
  #   enable = true;
  #   # man I whish dnssec would be viable to use
  #   dnssec = "false";
  #   llmnr = "false";
  #   # Disable local DNS stub listener on 127.0.0.53
  #   fallbackDns = [
  #     "1.1.1.1"
  #     "2606:4700:4700::1111"
  #     "8.8.8.8"
  #     "2001:4860:4860::8844"
  #   ];
  #   extraConfig = ''
  #     Domains=~.
  #     MulticastDNS=true
  #     DNSStubListener=no
  #   '';
  # };
  age.secrets.preshared-key = {
    file = "${peerPresharedKeyPath nodeName opnsense secretsPath}";
    mode = "640";
    owner = "systemd-network";
  };
  age.secrets.private-key = {
    file = peerPrivateKeyPath nodeName secretsPath;
    mode = "640";
    owner = "systemd-network";
  };

  systemd.network.networks = {
    "10-wan" = {
      address = [
        icfg.hostCidrv4
        icfg.hostCidrv6
      ];
      gateway = ["fe80::1"];
      routes = [
        {Destination = "172.31.1.1";}
        {
          Gateway = icfg.gateway.cidrv4; #"172.31.1.1";
          GatewayOnLink = true;
        }
      ];
      matchConfig.MACAddress = icfg.mac;
      networkConfig.IPv6PrivacyExtensions = "yes";
      linkConfig.RequiredForOnline = "routable";
    };
    "50-${wgName}" = {
      # name = "${wgName}";
      matchConfig.Name = "wg0";
      address = ["10.46.0.90/24"];
      networkConfig = {
        IPv4Forwarding = true;
        # If DNS requests should go to a specific nameserver when the tunnel is
        # established, uncomment this line and set it to the address of that
        # nameserver. But see the note at the bottom of this page.
        DNS = "1.1.1.1";
      };
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = ["wan"];
  networking.nftables.chains.forward.dnat = {
    after = ["conntrack"];
    rules = ["ct status dnat accept"];
  };
  # networking.nftables.ruleset = ''
  #   table inet wg-wg0 {
  #     chain preraw {
  #       type filter hook prerouting priority raw; policy accept;
  #       iifname != "wg0" ip daddr ${wgIpv4} fib saddr type != local drop
  #       iifname != "wg0" ip6 daddr ${wgIpv6} fib saddr type != local drop
  #     }
  #     chain premangle {
  #       type filter hook prerouting priority mangle; policy accept;
  #       meta l4proto udp meta mark set ct mark
  #     }
  #     chain postmangle {
  #       type filter hook postrouting priority mangle; policy accept;
  #       meta l4proto udp meta mark ${toString wgFwMark} ct mark set meta mark
  #     }
  #   }
  # '';

  # Open the udp port for the wireguard endpoint in the firewall
  networking.firewall.allowedUDPPorts = [51820];
  # wireguard.proxy-public.server = {
  #   host = config.networking.fqdn;
  #   port = 51443;
  #   reservedAddresses = ["10.43.0.0/24" "fd00:43::/120"];
  #   openFirewall = true;
  # };
  # wireguard.proxy-vps.server = {
  #   host = config.networking.fqdn;
  #   port = 51443;
  #   reservedAddresses = ["10.46.0.0/24" "fd00:43::/120"];
  #   openFirewall = true;
  # };
  systemd.network = {
    # enable = true;
    netdevs = {
      "40-proxy-vps" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1300";
        };
        wireguardConfig = {
          PrivateKeyFile = config.age.secrets.private-key.path;
          ListenPort = 51820;
        };
        wireguardPeers = [
          {
            PublicKey = "68vTxFdpgtwE6+RGvWFxVugx1KGoCZCq+IGVaczPyxM="; #builtins.readFile (peerPublicKeyPath nodeName secretsPath); #"GgyruHwl/IUc31jy05eqLUMk3dmS4796zwTydbt+UiY=";
            PresharedKeyFile = config.age.secrets.preshared-key.path;
            AllowedIPs = ["10.46.0.1/32" "10.15.40.21/32"];
            PersistentKeepalive = 25;
            Endpoint = "92.116.142.216:51820";
          }
        ];
      };
    };
  };

  # # If requested, create firewall rules for the network / specific participants and open ports.
  # networking.nftables.firewall = let
  #   inherit (config.networking.nftables.firewall) localZoneName;
  # in {
  #   zones =
  #     {
  #       # Parent zone for the whole interface
  #       "wg-${wgCfg.linkName}".interfaces = [wgCfg.linkName];
  #     }
  #     // listToAttrs (flip map participatingNodes (
  #       peer: let
  #         peerCfg = wgCfgOf peer;
  #       in
  #         # Subzone to specifically target the peer
  #         nameValuePair "wg-${wgCfg.linkName}-node-${peer}" {
  #           parent = "wg-${wgCfg.linkName}";
  #           ipv4Addresses = [peerCfg.ipv4];
  #           ipv6Addresses = [peerCfg.ipv6];
  #         }
  #     ));

  #   rules =
  #     {
  #       # Open ports for whole network
  #       "wg-${wgCfg.linkName}-to-${localZoneName}" = {
  #         from = ["wg-${wgCfg.linkName}"];
  #         to = [localZoneName];
  #         ignoreEmptyRule = true;

  #         inherit
  #           (wgCfg.firewallRuleForAll)
  #           allowedTCPPorts
  #           allowedUDPPorts
  #           ;
  #       };
  #     }
  #     # Open ports for specific nodes network
  #     // listToAttrs (flip map participatingNodes (
  #       peer:
  #         nameValuePair "wg-${wgCfg.linkName}-node-${peer}-to-${localZoneName}" (
  #           mkIf (wgCfg.firewallRuleForNode ? ${peer}) {
  #             from = ["wg-${wgCfg.linkName}-node-${peer}"];
  #             to = [localZoneName];
  #             ignoreEmptyRule = true;

  #             inherit
  #               (wgCfg.firewallRuleForNode.${peer})
  #               allowedTCPPorts
  #               allowedUDPPorts
  #               ;
  #           }
  #         )
  #     ));
  # };
}
