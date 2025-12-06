{
  config,
  globals,
  secretsPath,
  pkgs,
  ...
}: let
  influxdbDomain = "influxdb.${globals.domains.me}";
  influxdbPort = 8086;

  certloc = "/var/lib/acme-sync/czichy.com";
in {
  # |----------------------------------------------------------------------| #
  globals.services.influxdb.domain = influxdbDomain;
  networking.hostName = "HL-3-RZ-INFLUX-01";

  networking.firewall = {
    allowedTCPPorts = [8086];
    allowedUDPPorts = [8086];
  };

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${influxdbDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                # Da der innere Caddy ein eigenes Zertifikat ausstellt,
                # muss die Überprüfung auf dem äußeren Caddy übersprungen werden.
                # Dies ist ein Workaround, wenn die Zertifikatskette nicht vertrauenswürdig ist.
                tls_insecure_skip_verify
                # tls_server_name stellt sicher, dass der Hostname für die TLS-Handshake übermittelt wird.
            	tls_server_name ${influxdbDomain}
            }
        }

        # tls ${certloc}/fullchain.pem ${certloc}/key.pem {
        #   protocols tls1.3
        # }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${influxdbDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-INFLUX-01".ipv4}:${toString influxdbPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  # |----------------------------------------------------------------------| #
  age.secrets.influxdb-admin-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/admin-password.age";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-admin-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/admin-token.age";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-user-telegraf-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/telegraf-token.age";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-user-smart-home-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/smart-home-token.age";
    mode = "440";
    group = "influxdb2";
  };

  age.secrets.influxdb-user-home_assistant-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/home_assistant-token.age";
    mode = "440";
    group = "influxdb2";
  };
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/influxdb2";
      user = "influxdb2";
      group = "influxdb2";
      mode = "0700";
    }
  ];

  topology.self.services.influxdb2.info = "https://${influxdbDomain}";
  services.influxdb2 = {
    enable = true;
    settings = {
      reporting-disabled = true;
      http-bind-address = "0.0.0.0:${toString influxdbPort}";
    };
    provision = {
      enable = true;
      initialSetup = {
        organization = "default";
        bucket = "default";
        passwordFile = config.age.secrets.influxdb-admin-password.path;
        tokenFile = config.age.secrets.influxdb-admin-token.path;
      };
      organizations.machines = {
        buckets.telegraf = {};
        auths = {
          telegraf = {
            readBuckets = ["telegraf"];
            writeBuckets = ["telegraf"];
            tokenFile =
              config.age.secrets."influxdb-user-telegraf-token".path;
          };
        };
      };
      organizations.home = {
        buckets = {
          home_assistant = {};
          smart-home = {};
        };
        auths = {
          smart-home = {
            readBuckets = ["smart-home"];
            writeBuckets = ["smart-home"];
            tokenFile =
              config.age.secrets."influxdb-user-smart-home-token".path;
          };
          home_assistant = {
            readBuckets = ["home_assistant"];
            writeBuckets = ["home_assistant"];
            tokenFile =
              config.age.secrets."influxdb-user-home_assistant-token".path;
          };
        };
      };
    };
  };

  environment.systemPackages = [pkgs.influxdb2-cli];

  systemd.services.grafana.serviceConfig.RestartSec = "60"; # Retry every minute
}
