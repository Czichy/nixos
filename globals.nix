{config, ...}
: let
  inherit (config) globals;
in {
  globals = {
    net = {
      home-wan = {
        cidrv4 = "192.168.1.0/24";
        hosts.fritzbox.id = 1;
        hosts.HL-1-MRZ-SBC-01.id = 2;
        hosts.HL-1-OZ-PC-01.id = 62;
      };

      home-lan = {
        cidrv4 = "192.168.1.0/24";
        cidrv6 = "fd10::/64";
        hosts.HL-1-MRZ-SBC-01.id = 1;
        # hosts.sire.id = 2;
        # hosts.HL-1-DMZ-SBC-01-adguardhome.id = 3;
        # hosts.HL-1-DMZ-SBC-01-web-proxy.id = 4;
        # hosts.sire-samba.id = 10;
      };

      # v-lan = {
      #   cidrv4 = "10.15.40.0/24";
      #   cidrv6 = "fd10::/64";
      #   hosts.HL-1-MRZ-SBC-01.id = 1;
      #   hosts.sire.id = 2;
      #   hosts.HL-1-MRZ-SBC-01-adguardhome.id = 10;
      #   hosts.HL-1-MRZ-SBC-01-web-proxy.id = 11;
      #   hosts.sire-samba.id = 20;
      # };

      vlan40 = {
        cidrv4 = "10.15.40.0/24";
        cidrv6 = "fd10::/64";
        hosts.HL-1-MRZ-SBC-01.id = 1;
        hosts.sire.id = 2;
        hosts.HL-1-MRZ-SBC-01-adguardhome.id = 10;
        hosts.HL-1-MRZ-SBC-01-web-proxy.id = 11;
        hosts.sire-samba.id = 20;
      };

      proxy-home = {
        cidrv4 = "10.44.0.0/24";
        cidrv6 = "fd00:44::/120";
      };
    };
    monitoring = {
      dns = {
        cloudflare = {
          server = "1.1.1.1";
          domain = ".";
          network = "internet";
        };

        google = {
          server = "8.8.8.8";
          domain = ".";
          network = "internet";
        };
      };

      ping = {
        cloudflare = {
          hostv4 = "1.1.1.1";
          hostv6 = "2606:4700:4700::1111";
          network = "internet";
        };

        google = {
          hostv4 = "8.8.8.8";
          hostv6 = "2001:4860:4860::8888";
          network = "internet";
        };

        fritz-box = {
          hostv4 = globals.net.home-wan.hosts.fritzbox.ipv4;
          network = "home-wan";
        };
      };
    };
  };
}
