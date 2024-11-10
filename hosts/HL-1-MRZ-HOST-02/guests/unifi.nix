{
  config,
  globals,
  pkgs,
  ...
}: let
  unifiDomain = "unifi.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
in {
  networking.hostName = "HL-3-RZ-UNIFI-01";
  globals.services.unifi.domain = unifiDomain;
  globals.monitoring.dns.unifi = {
    server = globals.net.vlan40.hosts.HL-3-RZ-DNS-01.ipv4;
    domain = ".";
    network = "vlan40";
  };
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${unifiDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${unifiDomain}
            }
        }

        tls ${certloc}/cert.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-SBC-01-caddy = {
    services.caddy = {
      virtualHosts."${unifiDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-DNS-01".ipv4}:${toString config.services.adguardhome.port}
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/AdGuardHome";
      mode = "0700";
    }
  ];

  unifi = {
    enable = true;
    unifiPackage = pkgs.unifi8;
    openFirewall = true;
    maximumJavaHeapSize = 1024;
  };

  topology.self.services.unifi.info = "https://" + unifiDomain;

  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
