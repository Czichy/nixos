{globals, ...}: let
  macAddress_enp39s0 = "2c:f0:5d:9f:10:37";
in {
  topology.self.interfaces.enp39s0 = {};
  networking.firewall.checkReversePath = false;
  # |----------------------------------------------------------------------| #
  systemd.network.netdevs."10-trust" = {
    netdevConfig = {
      Kind = "vlan";
      Name = "trust";
      Description = "Trust VLAN10 OZ";
    };
    vlanConfig.Id = 10;
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
    "20-enp30s0-untagged" = {
      # matchConfig.MACAddress = config.repo.secrets.local.networking.interfaces.wan.mac;
      matchConfig.MACAddress = macAddress_enp39s0;
      # to prevent conflicts with vlan networks as they have the same MAC
      matchConfig.Type = "ether";
      # address = ["10.15.1.62/24"];
      address = [
        "192.168.0.62/24"
        "192.168.1.62/24"
        "10.15.1.62/24"
      ];
      routes = [{Gateway = "10.15.1.99";}];
      # tag vlan on this link
      vlan = [
        "trust"
        "servers"
        "mgmt"
      ];
      networkConfig.LinkLocalAddressing = "no";
      linkConfig.RequiredForOnline = "carrier";
    };
    "30-trust" = {
      matchConfig.Name = "trust";
      matchConfig.Type = "vlan";
      address = [globals.net.vlan10.hosts.HL-1-OZ-PC-01.cidrv4];
      gateway = [globals.net.vlan10.hosts.HL-3-MRZ-FW-01.ipv4];
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "no";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "30-servers" = {
      matchConfig.Name = "servers";
      matchConfig.Type = "vlan";
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "yes";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    "30-mgmt" = {
      matchConfig.Name = "mgmt";
      matchConfig.Type = "vlan";
      bridgeConfig = {};
      networkConfig = {
        ConfigureWithoutCarrier = true;
        DHCP = "yes";
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
  # |----------------------------------------------------------------------| #
}
