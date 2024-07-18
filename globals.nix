{config, ...}
: let
  inherit (config) globals;
in {
  globals.monitoring.ping.ward = {
    network = "home-lan";
  };
  globals.net = {
    home-wan = {
      cidrv4 = "192.168.178.0/24";
      hosts.fritzbox.id = 1;
      hosts.ward.id = 2;
    };

    home-lan = {
      cidrv4 = "192.168.1.0/24";
      cidrv6 = "fd10::/64";
      hosts.ward.id = 1;
      hosts.sire.id = 2;
      hosts.ward-adguardhome.id = 3;
      hosts.ward-web-proxy.id = 4;
      hosts.sire-samba.id = 10;
    };

    v-lan = {
      cidrv4 = "192.168.122.0/24";
      cidrv6 = "fd10::/64";
      hosts.ward.id = 175;
      hosts.sire.id = 2;
      hosts.ward-adguardhome.id = 3;
      hosts.ward-web-proxy.id = 4;
      hosts.sire-samba.id = 10;
    };

    proxy-home = {
      cidrv4 = "10.44.0.0/24";
      cidrv6 = "fd00:44::/120";
    };
  };
}
