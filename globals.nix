{config, ...}
: let
  inherit (config) globals;
in {
  globals = {
    domains.me = "czichy.com";
    net = {
      #VLAN1
      home-wan = {
        cidrv4 = "10.15.1.0/24";
        hosts.opnsense.id = 99;
        hosts.HL-1-MRZ-SBC-01.id = 254;
        hosts.HL-1-OZ-PC-01.id = 62;
      };

      #TRUST
      vlan10 = {
        cidrv4 = "10.15.10.0/24";
        hosts.opnsense.id = 99;
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 254;
      };

      #GUEST
      vlan20 = {
        cidrv4 = "10.15.20.0/24";
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 254;
      };

      #Security
      vlan30 = {
        cidrv4 = "10.15.30.0/24";
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 254;
      };
      #Server
      vlan40 = {
        cidrv4 = "10.15.40.0/24";
        cidrv6 = "fd10::/64";
        hosts.opnsense.id = 99;
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 20;
        # hosts.sire.id = 2;
        hosts.HL-1-MRZ-SBC-01-adguardhome.id = 21;
        hosts.HL-1-MRZ-SBC-01-vaultwarden.id = 22;
        hosts.HL-1-MRZ-SBC-01-web-proxy.id = 11;
        # hosts.sire-samba.id = 20;
      };

      #IoT
      vlan60 = {
        cidrv4 = "10.15.60.0/24";
        # cidrv6 = "fd10::/64";
        # hosts.HL-1-OZ-PC-01.id = 62;
        # hosts.HL-1-MRZ-SBC-01.id = 254;
      };

      #DMZ
      vlan70 = {
        cidrv4 = "10.15.70.0/24";
        # cidrv6 = "fd10::/64";
        # hosts.HL-1-OZ-PC-01.id = 62;
        # hosts.HL-1-MRZ-SBC-01.id = 254;
      };

      #Management
      vlan100 = {
        cidrv4 = "10.15.100.0/24";
        # cidrv6 = "fd10::/64";
        hosts.opnsense.id = 99;
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 20;
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
