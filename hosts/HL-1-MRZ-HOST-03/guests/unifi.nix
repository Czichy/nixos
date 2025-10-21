{
  globals,
  pkgs,
  hostName,
  ...
}: let
  unifiDomain = "unifi.czichy.com";
  certloc = "/var/lib/acme-sync/czichy.com";
in {
  # |----------------------------------------------------------------------| #
  microvm.mem = 1024 * 3;
  microvm.vcpu = 4;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;
  globals.services.unifi.domain = unifiDomain;
  globals.monitoring.dns.unifi = {
    server = globals.net.vlan40.hosts.HL-3-RZ-DNS-01.ipv4;
    domain = ".";
    network = "vlan40";
  };
  networking.firewall = {
    allowedTCPPorts = [
      8080 # Port for UAP to inform controller.
      8880 # Port for HTTP portal redirect, if guest portal is enabled.
      8843 # Port for HTTPS portal redirect, ditto.
      8443 # Port for HTTPS portal redirect, ditto.
      6789 # Port for UniFi mobile speed test.
    ];
    allowedUDPPorts = [
      5514
      3478 # UDP port used for STUN.
      10001 # UDP port used for device discovery.
    ];
  };
  # |----------------------------------------------------------------------| #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${unifiDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${unifiDomain}
            }
        }

        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${unifiDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-UNIFI-01".ipv4}:8443
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/var/lib/unifi";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #

  services.unifi = {
    enable = true;
    unifiPackage = pkgs.unifi;
    mongodbPackage = pkgs.mongodb-ce;
    openFirewall = false;
    maximumJavaHeapSize = 1024;
  };

  # |----------------------------------------------------------------------| #
  # topology.self.services.unifi = {
  # info = "https://" + unifiDomain;
  # name = "Unifi Controller";
  # };
}
