{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  ...
}:
let
  paperlessDomain = "paperless.${globals.domains.me}";
  paperlessAiDomain = "paperless-ai.${globals.domains.me}";
  paperlessPort = config.services.paperless.port;
  paperlessAiPort = 3000;
  certloc = "/var/lib/acme-sync/czichy.com";
  ollamaUrl = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";

  oauth2SecretFile = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-paperless.age";
  hasOAuth2Secret = builtins.pathExists oauth2SecretFile;

  paperlessAiTokenFile = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/paperless/paperless-ai-token.age";
  hasPaperlessAiToken = builtins.pathExists paperlessAiTokenFile;

  metadata = import ./paperless/metadata.nix;
in
{
  microvm.mem = 1024 * 4;
  microvm.vcpu = 4;

  networking.hostName = "HL-3-RZ-PAPERLESS-01";
  tensorfiles.services.monitoring.node-exporter.enable = true;

  # |----------------------------------------------------------------------| #
  networking.firewall.allowedTCPPorts = [
    paperlessPort
    paperlessAiPort
  ];

  # |----------------------------------------------------------------------| #
  # Äußerer Caddy (PAZ-PROXY-01) → innerer Caddy (HOST-02-caddy) via HTTPS
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy.virtualHosts."${paperlessDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
        transport http {
          tls_insecure_skip_verify
          tls_server_name ${paperlessDomain}
        }
        header_up Host {http.request.host}
      }
      import czichy_headers
    '';
  };

  # Innerer Caddy (HOST-02-caddy) → Paperless-MicroVM
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy.virtualHosts."${paperlessDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-PAPERLESS-01".ipv4}:${toString paperlessPort} {
        # Große Uploads erlauben (Scans, PDFs)
        header_up Host {http.request.host}
      }
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
        protocols tls1.3
      }
      import czichy_headers
    '';

    # paperless-ai Konfig-UI (Sidecar-Container, kein eigener Auth)
    services.caddy.virtualHosts."${paperlessAiDomain}".extraConfig = ''
      reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-PAPERLESS-01".ipv4}:${toString paperlessAiPort}
      tls ${certloc}/fullchain.pem ${certloc}/key.pem {
        protocols tls1.3
      }
      import czichy_headers
    '';
  };

  # paperless-ai auch über äußeren Proxy
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy.virtualHosts."${paperlessAiDomain}".extraConfig = ''
      reverse_proxy https://10.15.70.1:443 {
        transport http {
          tls_insecure_skip_verify
          tls_server_name ${paperlessAiDomain}
        }
        header_up Host {http.request.host}
      }
      import czichy_headers
    '';
  };

  # |----------------------------------------------------------------------| #
  globals.services.paperless = {
    domain = paperlessDomain;
    homepage = {
      enable = true;
      name = "Paperless-ngx";
      icon = "sh-paperless-ngx";
      description = "Dokumentenverwaltung mit OCR, Volltextsuche und Auto-Tagging";
      category = "Documents & Notes";
      priority = 5;
      abbr = "PL";
      widget = {
        type = "paperlessngx";
        url = "https://${paperlessDomain}";
        key = "{{HOMEPAGE_VAR_PAPERLESS_TOKEN}}";
      };
    };
  };

  globals.services.paperless-ai = {
    domain = paperlessAiDomain;
    homepage = {
      enable = true;
      name = "Paperless-AI";
      icon = "sh-paperless-ai";
      description = "LLM-basiertes Auto-Tagging via Ollama für Paperless";
      category = "Documents & Notes";
      priority = 6;
      abbr = "PA";
    };
  };

  globals.monitoring.http.paperless = {
    url = "https://${paperlessDomain}";
    expectedBodyRegex = "Paperless-ngx";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  topology.self.services.paperless.info = "https://${paperlessDomain}";

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/paperless";
      user = "paperless";
      group = "paperless";
      mode = "0750";
    }
    {
      directory = "/var/lib/paperless-ai";
      user = "paperless";
      group = "paperless";
      mode = "0750";
    }
    "/var/lib/containers"
  ];

  # |----------------------------------------------------------------------| #
  age.secrets.paperless-admin-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/paperless/admin-password.age";
    mode = "440";
    group = "paperless";
  };

  age.secrets.paperless-oauth2-client-secret = lib.mkIf hasOAuth2Secret {
    file = oauth2SecretFile;
    mode = "440";
    group = "paperless";
  };

  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };
  age.secrets.restic-paperless = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/paperless/restic-paperless.age";
    mode = "440";
  };
  age.secrets.paperless-ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };
  age.secrets.paperless-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  age.secrets.hetzner-storage-box-ssh-key = {
    file = secretsPath + "/hetzner/storage-box/ssh_key.age";
    mode = "400";
  };

  # Token für paperless-ai → paperless API. Wird im paperless-UI erstellt.
  age.secrets.paperless-ai-token = lib.mkIf hasPaperlessAiToken {
    file = paperlessAiTokenFile;
    mode = "440";
  };

  # |----------------------------------------------------------------------| #
  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    passwordFile = config.age.secrets.paperless-admin-password.path;

    # Virtiofs-gemountetes ZFS-Dataset (bunker/paperless)
    consumptionDir = "/paperless/consume";
    mediaDir = "/paperless/media";

    settings = {
      PAPERLESS_URL = "https://${paperlessDomain}";
      # Erlaube paperless.czichy.com extern + 10.15.40.16/localhost intern (paperless-ai)
      PAPERLESS_ALLOWED_HOSTS = lib.concatStringsSep "," [
        paperlessDomain
        globals.net.vlan40.hosts."HL-3-RZ-PAPERLESS-01".ipv4
        "localhost"
      ];
      PAPERLESS_CORS_ALLOWED_HOSTS = "https://${paperlessDomain}";
      # Innerer Caddy-Proxy
      PAPERLESS_TRUSTED_PROXIES = "10.15.70.1";

      # Kanidm OIDC – Secret wird dynamisch in paperless-web.script injiziert
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_SOCIALACCOUNT_PROVIDERS = builtins.toJSON {
        openid_connect = {
          OAUTH_PKCE_ENABLED = "True";
          APPS = [
            rec {
              provider_id = "kanidm";
              name = "Kanidm";
              client_id = "paperless";
              # secret wird via preStart injiziert
              settings.server_url = "https://${globals.services.kanidm.domain}/oauth2/openid/${client_id}/.well-known/openid-configuration";
            }
          ];
        };
      };

      # OCR: Deutsch + Englisch, fehlertolerант für digitale Signaturen
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = builtins.toJSON {
        continue_on_soft_render_error = true;
        invalidate_digital_signatures = true;
      };

      # Polling statt inotify (virtiofsd sendet keine inotify-Events)
      PAPERLESS_CONSUMER_POLLING = 5;
      PAPERLESS_CONSUMER_POLLING_DELAY = 5;
      PAPERLESS_CONSUMER_RECURSIVE = true;
      # Unterordner-Namen werden automatisch zu Tags
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;

      # Barcode-Unterstützung (ASN-Stempel, Trennseiten)
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      PAPERLESS_CONSUMER_BARCODE_SCANNER = "ZXING";

      # Dateinamensformat: user/datum_asn_titel
      PAPERLESS_FILENAME_FORMAT = "{{owner_username}}/{{created_year}}-{{created_month}}-{{created_day}}_{{asn}}_{{title}}";

      PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 8;
      PAPERLESS_TASK_WORKERS = 2;
      PAPERLESS_WEBSERVER_WORKERS = 2;
      PAPERLESS_ENABLE_COMPRESSION = false;

      # AI-Features sind in paperless-ngx 2.20 noch nicht enthalten – wir nutzen
      # stattdessen den paperless-ai Sidecar-Container (siehe systemd unten).
    };
  };

  systemd.services.paperless.serviceConfig.RestartSec = "60";

  # Kanidm OAuth2-Secret dynamisch in die OIDC-Konfiguration injizieren
  systemd.services.paperless-web.script = lib.mkIf hasOAuth2Secret (lib.mkBefore ''
    oidcSecret=$(< ${config.age.secrets.paperless-oauth2-client-secret.path})
    export PAPERLESS_SOCIALACCOUNT_PROVIDERS=$(
      ${lib.getExe pkgs.jq} <<< "$PAPERLESS_SOCIALACCOUNT_PROVIDERS" \
        --compact-output \
        --arg oidcSecret "$oidcSecret" \
        '.openid_connect.APPS.[0].secret = $oidcSecret'
    )
  '');

  # |----------------------------------------------------------------------| #
  # Idempotente Provisionierung von Document Types und Correspondents.
  # Liest metadata.nix und macht get_or_create + match-Update via Django ORM.
  # Läuft nach jedem Deploy automatisch.
  # |----------------------------------------------------------------------| #
  systemd.services.paperless-provision-metadata = {
    description = "Provision paperless document types & correspondents";
    after = [ "paperless-web.service" ];
    requires = [ "paperless-web.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = config.services.paperless.user;
      Group = "paperless";
      RemainAfterExit = false;
    };
    inherit (config.systemd.services.paperless-consumer) environment;
    script = ''
      /run/current-system/sw/bin/paperless-manage shell <<'PYEOF'
      import time
      from django.db import connection, OperationalError
      from documents.models import DocumentType, Correspondent

      # SQLite busy_timeout auf 30s damit wir den Consumer nicht ausbremsen
      connection.cursor().execute("PRAGMA busy_timeout = 30000")

      doc_types = ${builtins.toJSON metadata.documentTypes}
      correspondents = ${builtins.toJSON metadata.correspondents}

      def upsert(model, name, match, algorithm, retries=10):
          for attempt in range(retries):
              try:
                  obj, created = model.objects.update_or_create(
                      name=name,
                      defaults={
                          "match": match,
                          "matching_algorithm": algorithm,
                          "is_insensitive": True,
                      },
                  )
                  return obj, created
              except OperationalError as e:
                  if "locked" in str(e) and attempt < retries - 1:
                      time.sleep(3)
                      continue
                  raise

      print(f"Provisioning {len(doc_types)} document types...")
      for dt in doc_types:
          obj, created = upsert(DocumentType, dt["name"], dt["match"], dt["algorithm"])
          print(f"  {'[+]' if created else '[~]'} {obj.name}")

      print(f"Provisioning {len(correspondents)} correspondents...")
      for c in correspondents:
          obj, created = upsert(Correspondent, c["name"], c["match"], c["algorithm"])
          print(f"  {'[+]' if created else '[~]'} {obj.name}")

      print("Done.")
      PYEOF
    '';
  };

  # |----------------------------------------------------------------------| #
  services.restic.backups =
    let
      ntfy_pass = "$(cat ${config.age.secrets.paperless-ntfy-alert-pass.path})";
      ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
      slug = "https://health.czichy.com/ping/";

      script-post = host: site: ''
        pingKey="$(cat ${config.age.secrets.paperless-hc-ping.path})"
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
    in
    {
      paperless-backup = {
        initialize = true;
        repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-paperless";
        paths = [
          "/var/lib/paperless"   # DB, Thumbnails, Index
          "/paperless/media"     # Original-Dokumente
        ];
        exclude = [
          "/var/lib/paperless/log"
          "/var/lib/paperless/tmp"
        ];
        passwordFile = config.age.secrets.restic-paperless.path;
        rcloneConfigFile = config.age.secrets."rclone.conf".path;
        backupCleanupCommand = script-post config.networking.hostName "paperless";
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
          "--keep-yearly 2"
        ];
        timerConfig = {
          OnCalendar = "*-*-* 01:00:00";
          Persistent = true;
        };
      };

      paperless-backup-hetzner = {
        initialize = true;
        repository = "sftp:u581144@u581144.your-storagebox.de:/restic/${config.networking.hostName}-paperless";
        paths = [
          "/var/lib/paperless"
          "/paperless/media"
        ];
        exclude = [
          "/var/lib/paperless/log"
          "/var/lib/paperless/tmp"
        ];
        passwordFile = config.age.secrets.restic-paperless.path;
        extraOptions = [
          "sftp.args='-i ${config.age.secrets.hetzner-storage-box-ssh-key.path} -o StrictHostKeyChecking=accept-new'"
        ];
        backupCleanupCommand = script-post config.networking.hostName "paperless-hetzner";
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
          "--keep-yearly 2"
        ];
        timerConfig = {
          OnCalendar = "*-*-* 02:00:00";
          Persistent = true;
        };
      };
    };

  tensorfiles.services.resticMaintenance = {
    enable = true;
    ntfyPassFile = config.age.secrets.paperless-ntfy-alert-pass.path;
  };

  # |----------------------------------------------------------------------| #
  # paperless-ai – LLM-Sidecar via Podman-Container.
  # Pollt paperless-API alle 30 min, klassifiziert via Ollama, schreibt Tags
  # zurück. Konfiguration via Web-UI auf https://paperless-ai.czichy.com.
  # |----------------------------------------------------------------------| #
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Großer Image-Pull (~1.5 GB) – /var/tmp ist tmpfs (2 GB), reicht nicht.
  # podman/skopeo nutzt $TMPDIR für Layer-Staging beim Pull.
  systemd.services.podman-paperless-ai.environment.TMPDIR = "/var/lib/containers/tmp";
  systemd.tmpfiles.rules = [
    "d /var/lib/containers/tmp 0700 root root - -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers.paperless-ai = lib.mkIf hasPaperlessAiToken {
      image = "ghcr.io/clusterzx/paperless-ai:latest";
      autoStart = true;
      environment = {
        PUID = "315";
        PGID = "315";
        PAPERLESS_AI_PORT = toString paperlessAiPort;
        PAPERLESS_API_URL = "http://${globals.net.vlan40.hosts."HL-3-RZ-PAPERLESS-01".ipv4}:${toString paperlessPort}/api";
        AI_PROVIDER = "ollama";
        OLLAMA_API_URL = ollamaUrl;
        OLLAMA_MODEL = "mistral:7b";
        SCAN_INTERVAL = "*/30 * * * *";
        PROCESS_PREDEFINED_DOCUMENTS = "yes";
        ADD_AI_PROCESSED_TAG = "yes";
        AI_PROCESSED_TAG_NAME = "ai-processed";
      };
      environmentFiles = [
        config.age.secrets.paperless-ai-token.path
      ];
      ports = [
        "0.0.0.0:${toString paperlessAiPort}:${toString paperlessAiPort}"
      ];
      volumes = [
        "/var/lib/paperless-ai:/app/data"
      ];
      # Image braucht root + chown beim Start (entrypoint-Skript chown'd auf PUID/PGID)
    };
  };
}
