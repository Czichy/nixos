{
  config,
  globals,
  nodes,
  pkgs,
  secretsPath,
  hostName,
  lib,
  ...
}: let
  karakeepDomain = "karakeep.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";
  listenPort = 3000;
in {
  # |----------------------------------------------------------------------| #
  microvm.mem = 2029;
  microvm.vcpu = 2;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;
  tensorfiles.services.monitoring.node-exporter.enable = true;

  globals.services.karakeep = {
    domain = karakeepDomain;
    homepage = {
      enable = true;
      name = "Karakeep";
      icon = "sh-karakeep";
      description = "Self-hostable bookmark manager for links, notes and images with AI-based auto-tagging";
      category = "Documents & Notes";
      priority = 10;
      abbr = "KK";
    };
  };

  globals.monitoring.http.karakeep = {
    url = "https://${karakeepDomain}";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [listenPort];
  };

  # |----------------------------------------------------------------------| #
  # Äußerer Caddy (VPS) → innerer Caddy (HOST-02)
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${karakeepDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                tls_insecure_skip_verify
            	tls_server_name ${karakeepDomain}
            }
        }
        import czichy_headers
      '';
    };
  };

  # Innerer Caddy → MicroVM
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${karakeepDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-KARA-01".ipv4}:${toString listenPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  # Enthält NEXTAUTH_SECRET und weitere sensible Variablen
  age.secrets.karakeep-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/karakeep/karakeep-env.age";
    mode = "440";
    group = "karakeep";
  };

  age.secrets.restic-karakeep = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/karakeep/restic-karakeep.age";
    mode = "440";
  };

  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };

  age.secrets.karakeep-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # |----------------------------------------------------------------------| #
  services.karakeep = {
    enable = true;
    meilisearch.enable = true;
    browser.enable = true;
    environmentFile = config.age.secrets.karakeep-env.path;
    extraEnvironment = {
      NEXTAUTH_URL = "https://${karakeepDomain}";
      DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      # Ollama AI-Integration (nativ auf HOST-01, GPU-beschleunigt via CUDA)
      OLLAMA_BASE_URL = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";
      INFERENCE_TEXT_MODEL = "mistral:7b";
      # Kanidm OIDC/OAuth2 SSO
      # OAUTH_CLIENT_SECRET kommt aus karakeep-env.age (environmentFile)
      OAUTH_WELLKNOWN_URL = "https://${globals.services.kanidm.domain}/oauth2/openid/karakeep/.well-known/openid-configuration";
      OAUTH_CLIENT_ID = "karakeep";
      OAUTH_PROVIDER_NAME = "Kanidm (SSO)";
      OAUTH_AUTO_REDIRECT = "true";
      DISABLE_PASSWORD_AUTH = "true";
      OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKING = "true";
    };
  };

  # |----------------------------------------------------------------------| #
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.karakeep-hc-ping.path})"
      if [ $EXIT_STATUS -ne 0 ]; then
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
        -H 'Title: Backup (${site}) on ${host} failed!' \
        -H 'Tags: backup,restic,${host},${site}' \
        -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}/fail?create=1"
      else
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}?create=1"
      fi
    '';
  in {
    karakeep-backup = {
      initialize = true;
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-karakeep";
      paths = ["/var/lib/karakeep"];
      exclude = [
        "/var/lib/karakeep/cache"
      ];
      passwordFile = config.age.secrets.restic-karakeep.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
      backupCleanupCommand = script-post config.networking.hostName "karakeep";
      pruneOpts = [
        "--keep-daily 3"
        "--keep-weekly 3"
        "--keep-monthly 3"
        "--keep-yearly 3"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";
      };
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
        directory = "/var/lib/karakeep";
        user = "karakeep";
        group = "karakeep";
        mode = "0750";
      }
      {
        directory = "/var/lib/meilisearch";
        user = "meilisearch";
        group = "meilisearch";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #
}
