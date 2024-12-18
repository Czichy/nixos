{
  inputs,
  globals,
  config,
  ...
}
: let
  inherit (inputs.self) lib;
  inherit (config.lib.topology) mkConnection;
  macAddress_enp2s0 = "00:e0:4c:34:b6:40";
in {
  # networking.hostId = config.repo.secrets.local.networking.hostId;
  topology.self.interfaces.enp2s0 = {
    physicalConnections = [(mkConnection "HL-3-MRZ-FW-01" "enp1s0")];
  };

  globals.monitoring.ping.HL-1-MRZ-HOST-03 = {
    hostv4 = lib.net.cidr.ip globals.net.vlan100.hosts.HL-1-MRZ-HOST-03.cidrv4;
    hostv6 = lib.net.cidr.ip globals.net.vlan100.hosts.HL-1-MRZ-HOST-03.cidrv6;
    network = "vlan100";
  };

  # |----------------------------------------------------------------------| #
  #   # See <https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt> for docs on this
  #   # ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>
  #   # The server ip refers to the NFS server -- we don't need it.
  #   # "ip=${ipv4.address}::${ipv4.gateway}:${ipv4.netmask}:${hostName}-initrd:${networkInterface}:off:1.1.1.1"
  ## initrd luks_remote_unlock
  boot.kernelParams = ["ip=10.15.100.30::10.15.100.99:255.255.255.0:HL-1-MRZ-HOST-03-initrd:enp2s0:off"];
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

  # |----------------------------------------------------------------------| #
  systemd.network.networks = {
    "30-lan" = {
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.lan.mac;
      matchConfig.MACAddress = macAddress_enp2s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      # address = [
      #   "10.15.40.9/24"
      # ];
      # gateway = [globals.net.vlan40.hosts.opnsense.ipv4];
      # This interface should only be used from attached macvtaps.
      # So don't acquire a link local address and only wait for
      # this interface to gain a carrier.
      # routes = [{Gateway = "${globals.net.vlan40.hosts.HL-3-MRZ-FW-01.ipv4}";}];
      # routes = [{Gateway = "10.15.1.99";}];
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
        globals.net.vlan100.hosts.HL-1-MRZ-HOST-03.cidrv4
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
  # |----------------------------------------------------------------------| #
  networking.nftables.firewall = {
    zones.untrusted.interfaces = ["lan-self"];
  };
}
