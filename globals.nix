{config, ...}
: let
  inherit (config) globals;
in {
  globals = {
    domains.me = "czichy.com";
    domains.local = "czichy.com";
    net = {
      #VLAN1
      home-wan = {
        cidrv4 = "10.15.1.0/24";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        hosts.HL-1-MRZ-SBC-01.id = 254;
        hosts.HL-1-OZ-PC-01.id = 62;
      };

      #TRUST
      vlan10 = {
        cidrv4 = "10.15.10.0/24";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
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
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        # |------------------------------------| #
        hosts.HL-1-OZ-PC-01.id = 62;
        # |------------------------------------| #
        # Unifi Controller
        hosts.HL-3-RZ-UNIFI-01.id = 10;
        # |------------------------------------| #
        hosts.HL-1-MRZ-SBC-01.id = 20;
        # AdguardHome
        hosts.HL-3-RZ-DNS-01.id = 21;
        # Vaultwarden
        hosts.HL-3-RZ-VAULT-01.id = 22;
        # |------------------------------------| #
        hosts.HL-1-MRZ-HOST-01.id = 30;
        # Samba
        hosts.HL-3-RZ-SMB-01.id = 31;
        # InfluxDb
        hosts.HL-3-RZ-INFLUX-01.id = 32;
      };

      #IoT
      vlan60 = {
        cidrv4 = "10.15.60.0/24";
      };

      #DMZ
      vlan70 = {
        cidrv4 = "10.15.70.0/24";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        # Caddy
        hosts.HL-3-DMZ-PROXY-01.id = 1;
      };

      #Management
      vlan100 = {
        cidrv4 = "10.15.100.0/24";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-SBC-01.id = 20;
        hosts.HL-1-MRZ-HOST-01.id = 30;
        hosts.HL-1-MRZ-HOST-02.id = 10;
      };

      proxy-vps = {
        cidrv4 = "10.46.0.0/24";
        cidrv6 = "fd00:44::/120";
        # Caddy local
        hosts.HL-3-DMZ-PROXY-01.id = 1;
        # VPS
        hosts.HL-4-PAZ-PROXY-01.id = 90;
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
      };
    };
  };
}
