{
  config,
  globals,
  secretsPath,
  hostName,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # |----------------------------------------------------------------------| #
  docspellDomain = "search.${globals.domains.me}";

  certloc = "/var/lib/acme-sync/czichy.com";
  # |----------------------------------------------------------------------| #
in {
  microvm.mem = 1024 * 2;
  microvm.vcpu = 2;

  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/users/ina";
      # In the MicroVM
      mountPoint = "/shared/ina";
      tag = "ina";
      proto = "virtiofs";
    }
  ];

  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  age.secrets.mailer-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/forgejo/mailer-password.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    owner = config.services.forgejo.user;
    group = config.services.forgejo.group;
  };

  age.secrets.docspell-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  globals.services.forgejo.domain = docspellDomain;
  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      # config.services.docspell-restserver.bind.port
      # config.services.docspell-joex.bind.port
    ];
  };
  # |----------------------------------------------------------------------| #

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${docspellDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${docspellDomain}
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
      virtualHosts."${docspellDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-SEARCH-01".ipv4}:${toString config.services.forgejo.settings.server.HTTP_PORT}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;
    settings = {
      # WICHTIG: Meilisearch-Daten auf dem lokalen System speichern!
      # Dies wird vom `tmpfiles.rules` in flake.nix angelegt.
      dataDir = "/var/lib/meilisearch/data";
      masterKey = "TESTPASSWORD"; # ERSETZEN SIE DIES MIT EINEM STARKEM SCHLÜSSEL!
      httpAddr = "127.0.0.1:7700"; # Nur intern erreichbar
    };
    user = "meilisearch"; # Meilisearch unter diesem Benutzer ausführen
    group = "users";
  };

  environment.systemPackages = with pkgs; [
    meilisearch-dashboard # Stellt das Dashboard als statische Dateien bereit
  ];
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = config.services.maeilisearch.settings.dataDir;
        inherit (config.services.meilisearch) user group;
        mode = "0700";
      }
    ];
  };
  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  # environment.persistence."/state".directories = [
  #   {
  #     directory = config.services.forgejo.dump.backupDir;
  #     inherit (config.services.forgejo) user group;
  #     mode = "0700";
  #   }
  # ];

  fileSystems = lib.mkMerge [
    {
      "/state".neededForBoot = true;
    }
  ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
