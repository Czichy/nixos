{
  globals,
  inputs,
  config,
  ...
}: let
  inherit (inputs.self) lib;
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
  };

  networking.nftables.firewall.zones.untrusted.interfaces = ["wan"];
  networking.nftables.chains.forward.dnat = {
    after = ["conntrack"];
    rules = ["ct status dnat accept"];
  };

  # wireguard.proxy-public.server = {
  #   host = config.networking.fqdn;
  #   port = 51443;
  #   reservedAddresses = ["10.43.0.0/24" "fd00:43::/120"];
  #   openFirewall = true;
  # };
  wireguard.proxy-vps = {
    client.via = "HL-4-PAZ-PROXY-01";
    client.ipv4 = "10.46.0.90";
    # firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.vaultwarden.config.rocketPort];
  };
}
