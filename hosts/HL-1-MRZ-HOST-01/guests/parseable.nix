{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  ...
}:
# NOTE: To increase storage for all users:
#  $ runuser -u ente -- psql
#  ente => UPDATE subscriptions SET storage = 6597069766656;
# get One Time Password for user registration
# journalctl -au ente | grep SendEmailOTT | tail -n 1
let
  parseableDomain = "log.${globals.domains.me}";
  s3Domain = "log-s3.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";
in {
  networking.hostName = "HL-3-RZ-LOG-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [8000 8001 8002];
    allowedUDPPorts = [8000 8001 8002];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${parseableDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
            # Wichtige Einstellung: Deaktiviert die TLS-Zertifikatsprüfung
            tls_insecure_skip_verify
          	tls_server_name ${parseableDomain}
          }
          # header_up Host {http.request.host}
          # header_up X-Real-IP {http.request.remote}
          # header_up X-Forwarded-For {http.request.remote}
          # header_up X-Forwarded-Proto {http.request.scheme}
      }
      # tls ${certloc}/fullchain.pem ${certloc}/key.pem {
      #   protocols tls1.3
      # }
      import czichy_headers
    '';
  };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${parseableDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-LOG-01".ipv4}:8000 {
          # header_up Host {http.request.host}
          # header_up X-Real-IP {http.request.remote}
          # header_up X-Forwarded-For {http.request.remote}
          # header_up X-Forwarded-Proto {http.request.scheme}
          }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.parseable = {
    domain = parseableDomain;
    homepage = {
      enable = true;
      name = "Parseable";
      icon = "sh-parseable";
      description = "Cloud-native log analytics & observability platform with S3 storage";
      category = "Monitoring & Observability";
      priority = 30;
      abbr = "PS";
    };
  };
  # FIXME: also monitor from internal network
  # globals.monitoring.http.ente = {
  #   url = "https://${entePhotosDomain}";
  #   expectedBodyRegex = "Ente Photos";
  #   network = "internet";
  # };

  # |----------------------------------------------------------------------| #
  # | SYSTEM PACKAGES |
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    parseable
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.parseable-config = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/parseable/parseable.age";
    mode = "440";
    group = "parseable-user";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "parseable-user";
  };
  # |----------------------------------------------------------------------| #
  #
  systemd.services."parseable-s3" = {
    description = "Parseable";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    # type = "simple";
    # LimitNOFILE = 1048576;
    serviceConfig = {
      EnvironmentFile = config.age.secrets.parseable-config.path; #"/etc/default/parseable";
      WorkingDirectory = "/usr/local/";
      # User = "parseable-user";
      # Group = "parseable-user";
      Restart = "always";
      ExecStart = "${pkgs.parseable}/bin/parseable s3-store";
      AssertFileIsExecutable = "${pkgs.parseable}/bin/parseable";
    };
  };

  systemd.tmpfiles.rules = [
    "C /etc/default/parseable - - - - ${config.age.secrets.parseable-config.path}"
  ];

  systemd.tmpfiles.settings = {
    "10-working-dir" = {
      "/usr/local".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
    };
  };
}
