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
  s3Domain = "s3.${globals.domains.me}";

  certloc = "/var/lib/acme/czichy.com";
in {
  networking.hostName = "HL-3-RZ-S3-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [9000 9001];
    allowedUDPPorts = [9000 9001];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
            # Wichtige Einstellung: Deaktiviert die TLS-Zertifikatsprüfung
            tls_insecure_skip_verify
          	tls_server_name ${s3Domain}
          }
          # Diese Header sind entscheidend für die Weiterleitung
          header_up Host {http.request.host}
          header_up X-Real-IP {http.request.remote}
          header_up X-Forwarded-For {http.request.remote}
          header_up X-Forwarded-Proto {http.request.scheme}
      }
      # tls ${certloc}/cert.pem ${certloc}/key.pem {
      #   protocols tls1.3
      # }
      import czichy_headers
    '';
  };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-S3-01".ipv4}:9000 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote}
        header_up X-Forwarded-For {http.request.remote}
        header_up X-Forwarded-Proto {http.request.scheme}
      }
      tls ${certloc}/cert.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.s3.domain = s3Domain;
  # FIXME: also monitor from internal network
  # globals.monitoring.http.ente = {
  #   url = "https://${entePhotosDomain}";
  #   expectedBodyRegex = "Ente Photos";
  #   network = "internet";
  # };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/minio";
      user = "minio";
      group = "minio";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.minio-access-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-access-key.age";
    mode = "440";
    group = "parseable";
  };
  age.secrets.minio-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-secret-key.age";
    mode = "440";
    group = "parseable";
  };
  age.secrets.minio-root-credentials = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/s3/minio-root-credentials.age";
    mode = "440";
    group = "minio";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "vaultwarden";
  };
  # |----------------------------------------------------------------------| #
  services.minio = {
    enable = true;
    rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
    region = "germany-frankfurt-1";
  };
  systemd.services.minio = {
    environment.MINIO_SERVER_URL = "https://${s3Domain}";
    postStart = ''
      # Wait until minio is up
      ${lib.getExe pkgs.curl} --retry 5 --retry-connrefused --fail --no-progress-meter -o /dev/null "http://localhost:9000/minio/health/live"

      # Make sure bucket exists
      mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/ente
    '';
  };
}
