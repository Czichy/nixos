{
  inputs,
  globals,
  ...
}
: let
  inherit (inputs.self) lib;
  macAddress_enp1s0 = "a8:b8:e0:03:8d:e5";
  macAddress_enp4s0 = "a8:b8:e0:03:8d:e8";
in {
  # networking.hostId = config.repo.secrets.local.networking.hostId;
  topology.self.interfaces.enp4s0 = {};

  globals.monitoring.ping.HL-1-MRZ-HOST-01 = {
    hostv4 = lib.net.cidr.ip globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.cidrv6;
    network = "vlan40";
  };

  # |----------------------------------------------------------------------| #
  #   # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
  #   # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
  #   # The server ip refers to the NFS server -- we don't need it.
  #   # "ip=${ipv4.address}::${ipv4.gateway}:${ipv4.netmask}:${hostName}-initrd:${networkInterface}:off:1.1.1.1"
  ## initrd luks_remote_unlock
  boot.kernelParams = ["ip=10.15.100.30::10.15.100.99:255.255.255.0:HL-1-MRZ-HOST-01-initrd:enp1s0:off"];
  # |----------------------------------------------------------------------| #
  boot.initrd.systemd.network = {
    enable = true;
    networks."10-servers" = {
      matchConfig.MACAddress = macAddress_enp4s0;
      # address = [
      #   "10.15.1.30/24"
      # ];
      gateway = [globals.net.vlan40.hosts.HL-3-MRZ-FW-01.ipv4];
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      # networkConfig.LinkLocalAddressing = "no";
      networkConfig = {
        IPv4Forwarding = "yes";
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
    networks."30-mgmt" = {
      matchConfig.MACAddress = macAddress_enp1s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      # matchConfig.Name = "mgmt";
      # matchConfig.Type = "vlan";
      bridgeConfig = {};
      address = [
        globals.net.vlan100.hosts.HL-1-MRZ-HOST-01.cidrv4
      ];
      gateway = [globals.net.vlan100.hosts.HL-3-MRZ-FW-01.ipv4];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
  # Create a MACVTAP for ourselves too, so that we can communicate with
  # our guests on the same interface.
  systemd.network.netdevs."10-lan-self" = {
    netdevConfig = {
      Name = "lan-self";
      Kind = "macvlan";
    };
    # vlanConfig.Id = 40;
    extraConfig = ''
      [MACVLAN]
      Mode=bridge
    '';
  };
  systemd.network.netdevs."20-servers".netdevConfig = {
    Kind = "bridge";
    Name = "servers";
  };

  # |----------------------------------------------------------------------| #
  systemd.network.networks = {
    "30-servers" = {
      matchConfig.MACAddress = macAddress_enp4s0;
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      networkConfig.LinkLocalAddressing = "no";
      # linkConfig.RequiredForOnline = "carrier";
      extraConfig = ''
        [Network]
        MACVLAN=lan-self
      '';
      networkConfig = {
        IPv4Forwarding = "yes";
        IPv6PrivacyExtensions = "yes";
        MulticastDNS = true;
      };
      linkConfig.RequiredForOnline = "routable";
      gateway = [globals.net.vlan40.hosts.HL-3-MRZ-FW-01.ipv4];
    };

    "30-mgmt" = {
      matchConfig.MACAddress = macAddress_enp1s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      # matchConfig.Name = "mgmt";
      # matchConfig.Type = "vlan";
      bridgeConfig = {};
      address = [
        globals.net.vlan100.hosts.HL-1-MRZ-HOST-01.cidrv4
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
      # address = [globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.cidrv4];
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
  networking.nftables.firewall = {
    zones.untrusted.interfaces = ["lan-self"];
  };
}
