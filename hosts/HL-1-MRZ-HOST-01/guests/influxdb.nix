{
  config,
  globals,
  secretsPath,
  lib,
  nodes,
  pkgs,
  ...
}: let
  influxdbDomain = "influxdb.${globals.domains.me}";
  influxdbPort = 8086;

  certloc = "/var/lib/acme/czichy.com";
in {
  # age.secrets.github-access-token = {
  #   rekeyFile = config.node.secretsDir + "/github-access-token.age";
  #   mode = "440";
  #   group = "telegraf";
  # };

  # meta.telegraf.secrets."@GITHUB_ACCESS_TOKEN@" = config.age.secrets.github-access-token.path;
  # services.telegraf.extraConfig.outputs.influxdb_v2.urls = lib.mkForce ["http://localhost:${toString influxdbPort}"];

  # services.telegraf.extraConfig.inputs = {
  #   github = {
  #     interval = "10m";
  #     access_token = "@GITHUB_ACCESS_TOKEN@";
  #     repositories = [
  #       "oddlama/agenix-rekey"
  #       "oddlama/autokernel"
  #       "oddlama/gentoo-install"
  #       "oddlama/idmail"
  #       "oddlama/nix-config"
  #       "oddlama/nix-topology"
  #       "oddlama/vane"
  #     ];
  #   };
  # };

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
            	tls_server_name ${influxdbDomain}
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
      virtualHosts."${influxdbDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-INFLUX-01".ipv4}:${toString influxdbPort}
        tls ${certloc}/cert.pem ${certloc}/key.pem {
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
      organizations.machines.buckets.telegraf = {};
      organizations.home.buckets.home_assistant = {};
    };
  };

  environment.systemPackages = [pkgs.influxdb2-cli];

  systemd.services.grafana.serviceConfig.RestartSec = "60"; # Retry every minute
}
