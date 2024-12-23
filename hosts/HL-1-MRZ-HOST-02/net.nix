{
  inputs,
  globals,
  ...
}
: let
  inherit (inputs.self) lib;
  macAddress_enp4s0 = "60:be:b4:19:a8:4f";
in {
  # networking.hostId = config.repo.secrets.local.networking.hostId;
  topology.self.interfaces.enp4s0 = {
  };

  globals.monitoring.ping.HL-1-MRZ-HOST-02 = {
    hostv4 = lib.net.cidr.ip globals.net.vlan100.hosts.HL-1-MRZ-HOST-02.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.vlan100.hosts.HL-1-MRZ-HOST-02.cidrv6;
    network = "vlan100";
  };
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

  systemd.network.netdevs."10-mgmt" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "mgmt";
      Description = "Management VLAN100 MRZ";
    };
    vlanConfig.Id = 100;
  };

  systemd.network.netdevs."10-dmz" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "dmz";
      Description = "DMZ VLAN70 MRZ";
    };
    vlanConfig.Id = 70;
  };

  # |----------------------------------------------------------------------| #
  systemd.network.networks = {
    "30-lan" = {
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      matchConfig.MACAddress = macAddress_enp4s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      # address = [
      #   "10.15.40.154/24"
      #   "10.15.1.42/24"
      # ];
      # gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      # routes = [{Gateway = "10.15.1.99";}];
      vlan = [
        "servers"
        "mgmt"
        "dmz"
      ];
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVLAN=lan-self
      '';
    };
    "30-dmz" = {
      matchConfig.Name = "dmz";
      matchConfig.Type = "vlan";
      gateway = [globals.net.vlan70.hosts.HL-3-MRZ-FW-01.ipv4];
      linkConfig.RequiredForOnline = "routable";
    };

    "30-servers" = {
      matchConfig.Name = "servers";
      matchConfig.Type = "vlan";
      gateway = [globals.net.vlan40.hosts.HL-3-MRZ-FW-01.ipv4];
      linkConfig.RequiredForOnline = "routable";
    };

    "30-mgmt" = {
      matchConfig.Name = "mgmt";
      matchConfig.Type = "vlan";
      bridgeConfig = {};
      address = [
        globals.net.vlan100.hosts.HL-1-MRZ-HOST-02.cidrv4
      ];
      gateway = [globals.net.vlan100.hosts.HL-3-MRZ-FW-01.ipv4];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "30-lan-self" = {
      matchConfig.Name = "lan-self";
      gateway = [globals.net.vlan40.hosts.HL-3-MRZ-FW-01.ipv4];
      networkConfig = {
        IPv4Forwarding = "yes";
        IPv6PrivacyExtensions = "yes";
        IPv6SendRA = true;
        IPv6AcceptRA = false;
        DHCPPrefixDelegation = true;
        MulticastDNS = true;
      };
      dhcpPrefixDelegationConfig.Token = "::ff";
      linkConfig.RequiredForOnline = "routable";
    };

    # Remaining macvtap interfaces should not be touched.
    "90-macvtap-ignore" = {
      matchConfig.Kind = "macvtap";
      linkConfig.ActivationPolicy = "manual";
      linkConfig.Unmanaged = "yes";
    };
  };
}
