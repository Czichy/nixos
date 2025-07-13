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
let
  enteAccountsDomain = "accounts.photos.${globals.domains.me}";
  enteAlbumsDomain = "albums.photos.${globals.domains.me}";
  enteApiDomain = "api.photos.${globals.domains.me}";
  enteCastDomain = "cast.photos.${globals.domains.me}";
  entePhotosDomain = "photos.${globals.domains.me}";
  s3Domain = "s3.photos.${globals.domains.me}";

  certloc = "/var/lib/acme/czichy.com";
in {
  networking.hostName = "HL-3-RZ-ENTE-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [8080 9000 9001];
    allowedUDPPorts = [8080 9000 9001];
  };
  # |----------------------------------------------------------------------| #
  #
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
          	tls_server_name ${entePhotosDomain}
          }
      }
      tls ${certloc}/cert.pem ${certloc}/key.pem {
        protocols tls1.3
      }
      import czichy_headers
    '';
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
          transport http {
          	tls_server_name ${entePhotosDomain}
          }
      }
      tls ${certloc}/cert.pem ${certloc}/key.pem {
        protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:8080
      tls ${certloc}/cert.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
    services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:9000
      tls ${certloc}/cert.pem ${certloc}/key.pem {
         protocols tls1.3
      }
      import czichy_headers
    '';
  };
  # |----------------------------------------------------------------------| #
  globals.services.ente.domain = entePhotosDomain;
  # FIXME: also monitor from internal network
  globals.monitoring.http.ente = {
    url = "https://${entePhotosDomain}";
    expectedBodyRegex = "Ente Photos";
    network = "internet";
  };

  fileSystems."/storage".neededForBoot = true;
  environment.persistence."/storage".directories = [
    {
      directory = "/var/lib/minio";
      user = "minio";
      group = "minio";
      mode = "0750";
    }
  ];

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/ente";
      user = "ente";
      group = "ente";
      mode = "0750";
    }
  ];

  # |----------------------------------------------------------------------| #
  # NOTE: don't use the root user for access. In this case it doesn't matter
  # since the whole minio server is only for ente anyway, but it would be a
  # good practice.
  age.secrets.minio-access-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-access-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-secret-key.age";
    mode = "440";
    group = "ente";
  };
  age.secrets.minio-root-credentials = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
    mode = "440";
    group = "minio";
  };

  # base64 (url)
  age.secrets.ente-jwt = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-jwt.age";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-encryption-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-encryption-key.age";
    mode = "440";
    group = "ente";
  };
  # base64 (standard)
  age.secrets.ente-hash-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-hash-key.age";
    mode = "440";
    group = "ente";
  };
  # age.secrets.ente-smtp-password = {
  #   file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
  #   mode = "440";
  #   group = "ente";
  # };
  # |----------------------------------------------------------------------| #
  services.minio = {
    enable = true;
    rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
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

  systemd.services.ente.after = ["minio.service"];
  services.ente.api = {
    enable = true;
    enableLocalDB = true;
    domain = enteApiDomain;
    settings = {
      apps = {
        accounts = "https://${enteAccountsDomain}";
        cast = "https://${enteCastDomain}";
        public-albums = "https://${enteAlbumsDomain}";
      };

      webauthn = {
        rpid = enteAccountsDomain;
        rporigins = ["https://${enteAccountsDomain}"];
      };

      # FIXME: blocked on https://github.com/ente-io/ente/issues/5958
      # smtp = {
      #   host = config.repo.secrets.local.ente.mail.host;
      #   port = 465;
      #   email = config.repo.secrets.local.ente.mail.from;
      #   username = config.repo.secrets.local.ente.mail.user;
      #   password._secret = config.age.secrets.ente-smtp-password.path;
      # };

      s3 = {
        use_path_style_urls = true;
        b2-eu-cen = {
          endpoint = "https://${s3Domain}";
          region = "us-east-1";
          bucket = "ente";
          key._secret = config.age.secrets.minio-access-key.path;
          secret._secret = config.age.secrets.minio-secret-key.path;
        };
      };

      jwt.secret._secret = config.age.secrets.ente-jwt.path;
      key = {
        encryption._secret = config.age.secrets.ente-encryption-key.path;
        hash._secret = config.age.secrets.ente-hash-key.path;
      };
    };
  };

  # NOTE: services.ente.web is configured separately on both proxy servers!
  # nodes.sentinel.services.nginx = proxyConfig config.wireguard.proxy-sentinel.ipv4 "";
  # nodes.ward-web-proxy.services.nginx = proxyConfig config.wireguard.proxy-home.ipv4 ''
  #   allow ${globals.net.home-lan.vlans.home.cidrv4};
  #   allow ${globals.net.home-lan.vlans.home.cidrv6};
  #   # Firezone traffic
  #   allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
  #   allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
  #   deny all;
  # '';
}
# {
#   config,
#   globals,
#   lib,
#   pkgs,
#   secretsPath,
#   utils,
#   ...
# }: let
#   inherit
#     (lib)
#     getExe
#     mkDefault
#     ;
#   # NOTE: To increase storage for all users:
#   #  $ runuser -u ente -- psql
#   #  ente => UPDATE subscriptions SET storage = 6597069766656;
#   enteAccountsDomain = "accounts.photos.${globals.domains.me}";
#   enteAlbumsDomain = "albums.photos.${globals.domains.me}";
#   enteApiDomain = "api.photos.${globals.domains.me}";
#   enteCastDomain = "cast.photos.${globals.domains.me}";
#   entePhotosDomain = "photos.${globals.domains.me}";
#   s3Domain = "s3.photos.${globals.domains.me}";
#   defaultUser = "ente";
#   defaultGroup = "ente";
#   dataDir = "/persist/var/lib/ente";
#   yamlFormat = pkgs.formats.yaml {};
#   certloc = "/var/lib/acme/czichy.com";
#   settings = {
#     log-file = mkDefault "";
#     apps = {
#       accounts = "https://${enteAccountsDomain}";
#       cast = "https://${enteCastDomain}";
#       public-albums = "https://${enteAlbumsDomain}";
#     };
#     webauthn = {
#       rpid = enteAccountsDomain;
#       rporigins = ["https://${enteAccountsDomain}"];
#     };
#     # FIXME: blocked on https://github.com/ente-io/ente/issues/5958
#     # smtp = {
#     #   host = config.repo.secrets.local.ente.mail.host;
#     #   port = 465;
#     #   email = config.repo.secrets.local.ente.mail.from;
#     #   username = config.repo.secrets.local.ente.mail.user;
#     #   password._secret = config.age.secrets.ente-smtp-password.path;
#     # };
#     db = {
#       host = "/run/postgresql";
#       port = 5432;
#       name = "ente";
#       user = "ente";
#     };
#     s3 = {
#       use_path_style_urls = true;
#       b2-eu-cen = {
#         endpoint = "https://${s3Domain}";
#         region = "us-east-1";
#         bucket = "ente";
#         key._secret = config.age.secrets.minio-access-key.path;
#         secret._secret = config.age.secrets.minio-secret-key.path;
#       };
#     };
#     jwt.secret._secret = config.age.secrets.ente-jwt.path;
#     key = {
#       encryption._secret = config.age.secrets.ente-encryption-key.path;
#       hash._secret = config.age.secrets.ente-hash-key.path;
#     };
#   };
#   # ${utils.genJqSecretsReplacementSnippet settings "/run/ente/local.yaml"}
# in {
#   networking.hostName = "HL-3-RZ-ENTE-01";
#   globals.services.ente.domain = entePhotosDomain;
#   # |----------------------------------------------------------------------| #
#   networking.firewall = {
#     allowedTCPPorts = [8080 9000];
#   };
#   # |----------------------------------------------------------------------| #
#   nodes.HL-4-PAZ-PROXY-01 = {
#     # SSL config and forwarding to local reverse proxy
#     services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
#       reverse_proxy https://10.15.70.1:443 {
#           transport http {
#           	tls_server_name ${entePhotosDomain}
#           }
#       }
#       tls ${certloc}/cert.pem ${certloc}/key.pem {
#         protocols tls1.3
#       }
#       import czichy_headers
#     '';
#     services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
#       reverse_proxy https://10.15.70.1:443 {
#           transport http {
#           	tls_server_name ${entePhotosDomain}
#           }
#       }
#       tls ${certloc}/cert.pem ${certloc}/key.pem {
#         protocols tls1.3
#       }
#       import czichy_headers
#     '';
#   };
#   # reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:${toString influxdbPort}
#   nodes.HL-1-MRZ-HOST-02-caddy = {
#     services.caddy.virtualHosts."${enteApiDomain}".extraConfig = ''
#       reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:8080
#       tls ${certloc}/cert.pem ${certloc}/key.pem {
#          protocols tls1.3
#       }
#       import czichy_headers
#     '';
#     services.caddy.virtualHosts."${s3Domain}".extraConfig = ''
#       reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-ENTE-01".ipv4}:9000
#       tls ${certloc}/cert.pem ${certloc}/key.pem {
#          protocols tls1.3
#       }
#       import czichy_headers
#     '';
#   };
#   fileSystems."/storage".neededForBoot = true;
#   environment.persistence."/storage".directories = [
#     {
#       directory = "/var/lib/minio";
#       user = "minio";
#       group = "minio";
#       mode = "0750";
#     }
#   ];
#   environment.persistence."/persist".directories = [
#     {
#       directory = "/var/lib/ente";
#       user = "ente";
#       group = "ente";
#       mode = "0750";
#     }
#   ];
#   # |----------------------------------------------------------------------| #
#   # NOTE: don't use the root user for access. In this case it doesn't matter
#   # since the whole minio server is only for ente anyway, but it would be a
#   # good practice.
#   age.secrets.minio-access-key = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-access-key.age";
#     mode = "440";
#     group = "ente";
#   };
#   age.secrets.minio-secret-key = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-secret-key.age";
#     mode = "440";
#     group = "ente";
#   };
#   age.secrets.minio-root-credentials = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
#     mode = "440";
#     group = "minio";
#   };
#   # base64 (url)
#   age.secrets.ente-jwt = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-jwt.age";
#     mode = "440";
#     group = "ente";
#   };
#   # base64 (standard)
#   age.secrets.ente-encryption-key = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-encryption-key.age";
#     mode = "440";
#     group = "ente";
#   };
#   # base64 (standard)
#   age.secrets.ente-hash-key = {
#     file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/ente-hash-key.age";
#     mode = "440";
#     group = "ente";
#   };
#   # age.secrets.ente-smtp-password = {
#   #   file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ente/minio-root-credentials.age";
#   #   mode = "440";
#   #   group = "ente";
#   # };
#   # |----------------------------------------------------------------------| #
#   services.minio = {
#     enable = true;
#     rootCredentialsFile = config.age.secrets.minio-root-credentials.path;
#   };
#   systemd.services.minio = {
#     environment.MINIO_SERVER_URL = "https://${s3Domain}";
#     postStart = ''
#       # Wait until minio is up
#       ${lib.getExe pkgs.curl} --retry 5 --retry-connrefused --fail --no-progress-meter -o /dev/null "http://localhost:9000/minio/health/live"
#       # Make sure bucket exists
#       mkdir -p ${lib.escapeShellArg config.services.minio.dataDir}/ente
#     '';
#   };
#   # |----------------------------------------------------------------------| #
#   services.postgresql = {
#     enable = true;
#     ensureUsers = [
#       {
#         name = "ente";
#         ensureDBOwnership = true;
#       }
#     ];
#     ensureDatabases = ["ente"];
#   };
#   systemd.services.ente = {
#     description = "Ente.io Museum API Server";
#     after = ["network.target" "minio.service" "postgresql.service"];
#     requires = ["postgresql.service"];
#     wantedBy = ["multi-user.target"];
#     # ${utils.genJqSecretsReplacementSnippet settings "/run/ente/local.yaml"}
#     preStart = ''
#       # mkdir /run/ente
#       # Generate config including secret values. YAML is a superset of JSON, so we can use this here.
#        ${utils.genJqSecretsReplacementSnippet settings "/etc/ente/local.yaml"}
#       # Setup paths
#       mkdir -p ${dataDir}/configurations
#       ln -sTf /etc/ente/local.yaml ${dataDir}/configurations/local.yaml
#     '';
#     serviceConfig = {
#       ExecStart = getExe pkgs.museum;
#       Type = "simple";
#       Restart = "on-failure";
#       AmbientCapablities = [];
#       CapabilityBoundingSet = [];
#       LockPersonality = true;
#       MemoryDenyWriteExecute = true;
#       NoNewPrivileges = true;
#       PrivateMounts = true;
#       PrivateTmp = true;
#       PrivateUsers = false;
#       ProcSubset = "pid";
#       ProtectClock = true;
#       ProtectControlGroups = true;
#       ProtectHome = true;
#       ProtectHostname = true;
#       ProtectKernelLogs = true;
#       ProtectKernelModules = true;
#       ProtectKernelTunables = true;
#       ProtectProc = "invisible";
#       ProtectSystem = "strict";
#       RestrictAddressFamilies = [
#         "AF_INET"
#         "AF_INET6"
#         "AF_NETLINK"
#         "AF_UNIX"
#       ];
#       RestrictNamespaces = true;
#       RestrictRealtime = true;
#       RestrictSUIDSGID = true;
#       SystemCallArchitectures = "native";
#       SystemCallFilter = "@system-service";
#       UMask = "077";
#       BindReadOnlyPaths = [
#         "${pkgs.museum}/share/museum/migrations:${dataDir}/migrations"
#         "${pkgs.museum}/share/museum/mail-templates:${dataDir}/mail-templates"
#       ];
#       User = defaultUser;
#       Group = defaultGroup;
#       SyslogIdentifier = "ente";
#       # StateDirectory = "ente";
#       WorkingDirectory = dataDir;
#       # RuntimeDirectory = "ente";
#     };
#     # Environment MUST be called local, otherwise we cannot log to stdout
#     environment = {
#       ENVIRONMENT = "local";
#       GIN_MODE = "release";
#     };
#   };
#   users = {
#     users = {
#       "${defaultUser}" = {
#         description = "ente.io museum service user";
#         group = "${defaultGroup}";
#         isSystemUser = true;
#         home = dataDir;
#       };
#     };
#     groups."${defaultGroup}" = {};
#   };
#   # services.nginx = mkIf cfgApi.nginx.enable {
#   #   enable = true;
#   #   upstreams.museum = {
#   #     servers."localhost:8080" = {};
#   #     extraConfig = ''
#   #       zone museum 64k;
#   #       keepalive 20;
#   #     '';
#   #   };
#   #   virtualHosts.${cfgApi.domain} = {
#   #     forceSSL = mkDefault true;
#   #     locations."/".proxyPass = "http://museum";
#   #     extraConfig = ''
#   #       client_max_body_size 4M;
#   #     '';
#   #   };
#   # };
#   # |----------------------------------------------------------------------| #
#   systemd.tmpfiles.rules = [
#     "d /run/ente 0755 ente ente - -"
#     "d /etc/ente 0755 ente ente - -"
#     "d ${dataDir}/configurations 0755 ente ente - -"
#   ];
# }

