{config, ...}
: let
  inherit (config) globals;
in {
  globals = {
    domains.me = "czichy.com";
    domains.local = "czichy.com";
    net = {
      #TRUST
      vlan10 = {
        cidrv4 = "10.15.10.0/24";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 25;
        hosts.HL-1-MRZ-HOST-02.id = 254;
      };

      #GUEST
      vlan20 = {
        cidrv4 = "10.15.20.0/24";
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-HOST-02.id = 254;
      };

      #Security
      vlan30 = {
        cidrv4 = "10.15.30.0/24";
        # cidrv6 = "fd10::/64";
        hosts.HL-1-OZ-PC-01.id = 62;
        hosts.HL-1-MRZ-HOST-02.id = 254;
      };
      #Server
      vlan40 = {
        cidrv4 = "10.15.40.0/24";
        # cidrv6 = "fd10::/64";
        # OPNSense
        hosts.HL-3-MRZ-FW-01.id = 99;
        # |------------------------------------| #
        hosts.HL-1-OZ-PC-01.id = 25;
        # |------------------------------------| #
        hosts.HL-1-MRZ-HOST-01.id = 10;
        # Samba
        hosts.HL-3-RZ-SMB-01.id = 11;
        # InfluxDb
        hosts.HL-3-RZ-INFLUX-01.id = 12;
        # Syncthing
        hosts.HL-3-RZ-SYNC-01.id = 13;
        # Forgejo
        hosts.HL-3-RZ-GIT-01.id = 14;
        # IBKR Flex Downloader
        hosts.HL-3-RZ-IBKR-01.id = 15;
        # Docspell
        hosts.HL-3-RZ-DOCSPL-01.id = 16;
        # Ente
        hosts.HL-3-RZ-ENTE-01.id = 17;
        # Paperless
        hosts.HL-3-RZ-PAPERLESS-01.id = 18;
        # Meilisearch
        hosts.HL-3-RZ-SEARCH-01.id = 19;
        # |------------------------------------| #
        hosts.HL-1-MRZ-HOST-02.id = 20;
        # AdguardHome
        hosts.HL-3-RZ-DNS-01.id = 21;
        # Vaultwarden
        hosts.HL-3-RZ-VAULT-01.id = 22;
        # |------------------------------------| #
        # Unifi Controller
        hosts.HL-3-RZ-UNIFI-01.id = 31;
        # Minecraft Server
        hosts.HL-3-RZ-MC-01.id = 32;
        # Mosquitto
        hosts.HL-3-RZ-MQTT-01.id = 33;
        # Power Meter
        hosts.HL-3-RZ-POWER-02.id = 34;
        # node-red
        hosts.HL-3-RZ-RED-01.id = 35;
        # node-red
        hosts.HL-3-RZ-HASS-01.id = 36;
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
        hosts.HL-1-MRZ-HOST-01.id = 10;
        hosts.HL-1-MRZ-HOST-02.id = 20;
        hosts.HL-1-MRZ-HOST-03.id = 30;
        hosts.HL-1-OZ-PC-01.id = 25;
        hosts.HL-3-MRZ-FW-01.id = 99;
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
