{
  config,
  globals,
  ...
}: let
  adguardhomeDomain = "adguardhome.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
  # adguardhomeDomain = "adguardhome.${config.repo.secrets.global.domains.me}";
  filter-dir = "https://adguardteam.github.io/HostlistsRegistry/assets";
in {
  networking.hostName = "HL-1-MRZ-SBC-01-adguardhome";
  globals.services.adguardhome.domain = adguardhomeDomain;
  globals.monitoring.dns.adguardhome = {
    server = globals.net.home-lan.hosts.ward-adguardhome.ipv4;
    domain = ".";
    network = "home-lan";
  };
  #   smarthome.{{ secret_personal_url }} {
  # 	crowdsec
  # 	reverse_proxy https://10.10.10.10:443 {
  # 		transport http {
  # 			tls_server_name smarthome.{{ secret_personal_url }}
  # 		}
  # 	}
  # 	tls /home/{{ main_username }}/lego/certificates/_.{{ secret_personal_url }}.crt /home/{{ main_username }}/lego/certificates/_.{{ secret_personal_url }}.key
  # 	import personal_headers
  # }
  # nodes.HL-4-PAZ-PROXY-01 = {
  #   # SSL config and forwarding to local reverse proxy
  #   services.caddy = {
  #     virtualHosts."adguardhome.czichy.com".extraConfig = ''
  #       reverse_proxy https://10.15.70.1:443 {
  #           transport http {
  #           	tls_server_name adguardhome.czichy.com
  #           }
  #       }

  #       tls ${certloc}/cert.pem ${certloc}/key.pem {
  #         protocols tls1.3
  #       }
  #       import czichy_headers
  #     '';
  #   };
  # };
  nodes.HL-1-MRZ-SBC-01-caddy = {
    services.caddy = {
      virtualHosts."adguardhome.czichy.com".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-1-MRZ-SBC-01-adguardhome".ipv4}:${toString config.services.adguardhome.port}
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

  networking.firewall = {
    allowedTCPPorts = [53 80 443 3000];
    allowedUDPPorts = [53];
  };

  topology.self.services.adguardhome.info = "https://" + adguardhomeDomain;
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;
    settings = {
      dns = {
        # port = 53;
        # allowed_clients = [
        # ];
        #trusted_proxies = [];
        ratelimit = 300;
        bind_hosts = ["::"];
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "https://doh.mullvad.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          # FIXME: enable ipv6 "2606:4700:4700::1111"
          "8.8.8.8"
          # FIXME: enable ipv6 "2001:4860:4860::8844"
        ];
        dhcp.enabled = false;
      };
      filtering.rewrites =
        [
          # Undo the /etc/hosts entry so we don't answer with the internal
          # wireguard address for influxdb
          {
            # inherit (globals.services.influxdb) domain;
            # answer = config.repo.secrets.global.domains.me;
          }
        ]
        # Use the local mirror-proxy for some services (not necessary, just for speed)
        ++ map (domain: {
          inherit domain;
          answer = globals.net.home-lan.hosts.ward-web-proxy.ipv4;
        }) [
          # FIXME: dont hardcode, filter global service domains by internal state
          # globals.services.grafana.domain
          # globals.services.immich.domain
          # globals.services.influxdb.domain
          # "home.${config.repo.secrets.global.domains.me}"
          # "fritzbox.${config.repo.secrets.global.domains.me}"
        ];
      filters = [
        {
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
          enabled = true;
        }
        {
          name = "AdAway Default Blocklist";
          url = "https://adaway.org/hosts.txt";
          enabled = true;
        }
        {
          name = "OISD (Big)";
          url = "https://big.oisd.nl";
          enabled = true;
        }
      ];
    };
  };

  system.stateVersion = "24.05";
}
