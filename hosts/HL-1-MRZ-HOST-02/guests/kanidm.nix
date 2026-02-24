# Kanidm – Zentraler Identity & Access Management Service
#
# Kanidm läuft als MicroVM auf HOST-02 und stellt OAuth2/OIDC für alle
# externen Services bereit. Authentifizierung läuft über den oauth2-proxy
# auf HL-4-PAZ-PROXY-01.
#
# Architektur:
#   Browser → HL-4-PAZ-PROXY-01 (Caddy + oauth2-proxy)
#           → Kanidm Login (auth.czichy.com)
#           → Session-Cookie → Weiterleitung zum eigentlichen Service
#
# Kanidm benötigt TLS auch intern. Wir verwenden ein Self-Signed-Zertifikat,
# das via agenix verwaltet wird. Der externe Zugang läuft über den Caddy
# Reverse Proxy mit echtem Let's-Encrypt-Zertifikat.
#
# Alle Secrets sind mit builtins.pathExists abgesichert, damit der Build
# auch OHNE vorhandene .age-Dateien nicht fehlschlägt.
#
# Referenz: https://github.com/oddlama/nix-config/blob/main/hosts/ward/guests/kanidm.nix
#
# ══════════════════════════════════════════════════════════════════════════════
# SECRETS (im private-Repo anlegen vor dem ersten Deploy):
#
#   # Self-Signed TLS Zertifikat erzeugen:
#   openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout /tmp/kanidm.key -out /tmp/kanidm.crt -subj "/CN=auth.czichy.com" -addext "subjectAltName=DNS:auth.czichy.com"
#   open --raw /tmp/kanidm.crt | agenix -e ./hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.crt.age
#   open --raw /tmp/kanidm.key | agenix -e ./hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.key.age
#   rm /tmp/kanidm.key /tmp/kanidm.crt
#
#   # Admin-Passwörter:
#   openssl rand -base64 32 | agenix -e ./hosts/HL-1-MRZ-HOST-02/guests/kanidm/admin-password.age
#   openssl rand -base64 32 | agenix -e ./hosts/HL-1-MRZ-HOST-02/guests/kanidm/idm-admin-password.age
#
#   # OAuth2 Client-Secrets (eines pro aktivem Service):
#   # Hinweis: edu-search und open-webui laufen über web-sentinel und
#   # brauchen kein eigenes OAuth2-Secret.
#   # Deaktiviert: paperless, immich, linkwarden (keine aktiven MicroVMs)
#   for svc in [grafana forgejo web-sentinel] {
#     openssl rand -base64 32 | agenix -e $"hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-($svc).age"
#   }
#
#   # Restic-Backup Passwort:
#   openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/restic-kanidm.age
# ══════════════════════════════════════════════════════════════════════════════
{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  hostName,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Konfiguration
  # ---------------------------------------------------------------------------
  kanidmDomain = "auth.${globals.domains.me}";
  kanidmPort = 8443;
  certloc = "/var/lib/acme-sync/czichy.com";

  # Basis-Pfad für alle Kanidm-Secrets im private-Repo
  secretsBase = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/kanidm";

  # ---------------------------------------------------------------------------
  # Secret-Existenz-Prüfungen
  # ---------------------------------------------------------------------------
  # Wenn die .age-Dateien noch nicht existieren (vor dem ersten Deploy),
  # werden die entsprechenden Konfigurationsblöcke übersprungen.
  tlsCrtFile = secretsBase + "/kanidm-self-signed.crt.age";
  tlsKeyFile = secretsBase + "/kanidm-self-signed.key.age";
  adminPwFile = secretsBase + "/admin-password.age";
  idmAdminPwFile = secretsBase + "/idm-admin-password.age";
  resticFile = secretsBase + "/restic-kanidm.age";
  rcloneFile = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
  ntfyFile = secretsPath + "/ntfy-sh/alert-pass.age";

  hasTlsCrt = builtins.pathExists tlsCrtFile;
  hasTlsKey = builtins.pathExists tlsKeyFile;
  hasAdminPw = builtins.pathExists adminPwFile;
  hasIdmAdminPw = builtins.pathExists idmAdminPwFile;
  hasRestic = builtins.pathExists resticFile;
  hasRclone = builtins.pathExists rcloneFile;
  hasNtfy = builtins.pathExists ntfyFile;
  hasBackupSecrets = hasRestic && hasRclone;

  # Kanidm kann nur starten wenn TLS-Zertifikate vorhanden sind
  hasRequiredSecrets = hasTlsCrt && hasTlsKey && hasAdminPw && hasIdmAdminPw;

  # Backup-Verzeichnis (Kanidm online_backup schreibt hierhin)
  backupDir = "/var/lib/kanidm/backups";

  # Prüfe ob ein OAuth2-Secret existiert
  hasOAuth2Secret = name:
    builtins.pathExists (secretsBase + "/oauth2-${name}.age");

  # ---------------------------------------------------------------------------
  # Hilfsfunktionen für Secrets
  # ---------------------------------------------------------------------------
  mkKanidmSecret = file: extraAttrs:
    {
      inherit file;
      mode = "440";
      group = "kanidm";
    }
    // extraAttrs;

  # OAuth2-Secret definieren (nur wenn .age-Datei existiert)
  mkOAuth2Secret = name: let
    secretFile = secretsBase + "/oauth2-${name}.age";
  in
    lib.nameValuePair "kanidm-oauth2-${name}" (
      lib.mkIf (builtins.pathExists secretFile) (mkKanidmSecret secretFile {})
    );

  # Liste aller OAuth2-Clients (Services die eigene Kanidm-Auth nutzen)
  # Hinweis: edu-search und open-webui laufen über web-sentinel (oauth2-proxy)
  # und brauchen keinen eigenen OAuth2-Client.
  # Nur aktive MicroVM-Services auflisten!
  # Deaktiviert: paperless, immich, linkwarden (keine aktiven MicroVMs)
  oauth2Clients = [
    "grafana"
    "forgejo"
    "web-sentinel"
  ];
in {
  # ---------------------------------------------------------------------------
  # MicroVM-Ressourcen
  # ---------------------------------------------------------------------------
  # Kanidm ist sehr leichtgewichtig (Rust, ~50-100MB RAM).
  # 1 GB RAM und 2 vCPUs sind mehr als ausreichend.
  microvm.mem = 1024;
  microvm.vcpu = 2;

  networking.hostName = hostName;

  # ---------------------------------------------------------------------------
  # Globals: Kanidm als Service registrieren
  # ---------------------------------------------------------------------------
  globals.services.kanidm = {
    domain = kanidmDomain;
    homepage = {
      enable = true;
      name = "Kanidm";
      icon = "sh-kanidm";
      description = "Identity & Access Management (SSO/OAuth2)";
      category = "Infrastructure";
      requiresAuth = false; # Kanidm hat eigene Login-Seite
      priority = 5;
      abbr = "IAM";
    };
  };

  # Monitoring: Kanidm Health-Check
  globals.monitoring.http.kanidm = {
    url = "https://${globals.net.vlan40.hosts."HL-3-RZ-AUTH-01".ipv4}:${toString kanidmPort}/status";
    expectedBodyRegex = "true";
    network = "vlan40";
    skipTlsVerification = true; # Self-Signed Cert
  };

  # ---------------------------------------------------------------------------
  # Agenix Secrets
  # ---------------------------------------------------------------------------

  # TLS-Zertifikate (Kanidm erzwingt TLS, auch intern)
  age.secrets."kanidm-self-signed.crt" = lib.mkIf hasTlsCrt (mkKanidmSecret tlsCrtFile {});
  age.secrets."kanidm-self-signed.key" = lib.mkIf hasTlsKey (mkKanidmSecret tlsKeyFile {});

  # Admin-Passwörter
  age.secrets.kanidm-admin-password = lib.mkIf hasAdminPw (mkKanidmSecret adminPwFile {});
  age.secrets.kanidm-idm-admin-password = lib.mkIf hasIdmAdminPw (mkKanidmSecret idmAdminPwFile {});

  # OAuth2 Client-Secrets (eines pro Service, nur wenn .age-Datei existiert)
  # Hinweis: edu-search und open-webui brauchen kein eigenes Secret –
  # sie laufen über web-sentinel (oauth2-proxy auf PAZ-PROXY-01 / sentinel).
  age.secrets.kanidm-oauth2-grafana = lib.mkIf (hasOAuth2Secret "grafana") (mkKanidmSecret (secretsBase + "/oauth2-grafana.age") {});
  age.secrets.kanidm-oauth2-forgejo = lib.mkIf (hasOAuth2Secret "forgejo") (mkKanidmSecret (secretsBase + "/oauth2-forgejo.age") {});
  # Deaktiviert: paperless, immich, linkwarden haben keine aktiven MicroVMs
  # age.secrets.kanidm-oauth2-paperless = lib.mkIf (hasOAuth2Secret "paperless") (mkKanidmSecret (secretsBase + "/oauth2-paperless.age") {});
  # age.secrets.kanidm-oauth2-immich = lib.mkIf (hasOAuth2Secret "immich") (mkKanidmSecret (secretsBase + "/oauth2-immich.age") {});
  # age.secrets.kanidm-oauth2-linkwarden = lib.mkIf (hasOAuth2Secret "linkwarden") (mkKanidmSecret (secretsBase + "/oauth2-linkwarden.age") {});
  age.secrets.kanidm-oauth2-web-sentinel = lib.mkIf (hasOAuth2Secret "web-sentinel") (mkKanidmSecret (secretsBase + "/oauth2-web-sentinel.age") {});

  # Restic-Backup Secrets
  age.secrets.restic-kanidm = lib.mkIf hasRestic {
    file = resticFile;
    mode = "440";
    group = "kanidm";
  };
  age.secrets."rclone-kanidm.conf" = lib.mkIf hasRclone {
    file = rcloneFile;
    mode = "440";
    group = "kanidm";
  };
  age.secrets.kanidm-ntfy-alert-pass = lib.mkIf hasNtfy {
    file = ntfyFile;
    mode = "440";
    group = "kanidm";
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [kanidmPort];

  # ---------------------------------------------------------------------------
  # Reverse Proxy: Caddy auf HOST-02 (intern) + PAZ-PROXY-01 (extern)
  # ---------------------------------------------------------------------------

  # Interner Caddy: TLS-Terminierung + Weiterleitung
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${kanidmDomain}".extraConfig = ''
        reverse_proxy https://${globals.net.vlan40.hosts."HL-3-RZ-AUTH-01".ipv4}:${toString kanidmPort} {
            transport http {
                tls_insecure_skip_verify
                tls_server_name ${kanidmDomain}
            }
        }
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # Externer Caddy auf PAZ-PROXY-01 (VPS → interner Caddy)
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${kanidmDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                tls_insecure_skip_verify
                tls_server_name ${kanidmDomain}
            }
        }
        import czichy_headers
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Impermanence
  # ---------------------------------------------------------------------------
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/var/lib/kanidm";
        user = "kanidm";
        group = "kanidm";
        mode = "0700";
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Kanidm Server
  # ---------------------------------------------------------------------------
  services.kanidm = lib.mkIf hasRequiredSecrets {
    package = pkgs.kanidm_1_8.withSecretProvisioning;

    server.enable = true;

    server.settings = {
      domain = kanidmDomain;
      origin = "https://${kanidmDomain}";
      tls_chain = config.age.secrets."kanidm-self-signed.crt".path;
      tls_key = config.age.secrets."kanidm-self-signed.key".path;
      bindaddress = "0.0.0.0:${toString kanidmPort}";
      # Trust X-Forwarded-For vom Caddy Reverse Proxy

      # Online-Backup: Kanidm erstellt automatisch konsistente DB-Dumps
      # Die Dateien landen in backupDir und werden von restic gesichert.
      online_backup = {
        path = backupDir;
        schedule = "00 02 * * *"; # Täglich um 02:00 Uhr
        versions = 7; # 7 Tage lokale Backups behalten
      };
    };

    # Kanidm CLI-Client (für Admin-Zugriff auf der VM)
    client.enable = true;
    client.settings = {
      uri = "https://localhost:${toString kanidmPort}";
      verify_ca = false; # Self-Signed Cert
      verify_hostnames = false;
    };

    # =========================================================================
    # Deklarative Provisionierung: Benutzer, Gruppen, OAuth2-Clients
    # =========================================================================
    provision = {
      enable = true;
      adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
      idmAdminPasswordFile = config.age.secrets.kanidm-idm-admin-password.path;

      # --- Benutzer aus globals.kanidm.persons übernehmen ---
      inherit (globals.kanidm) persons;

      # =====================================================================
      # Gruppen
      # =====================================================================
      # Jeder Service bekommt eine *.access Gruppe (und optional *.admins).
      # Benutzer werden in globals.kanidm.persons ihren Gruppen zugeordnet.

      # --- Edu-Search ---
      groups."edu-search.access" = {};

      # --- Grafana ---
      groups."grafana.access" = {};
      groups."grafana.editors" = {};
      groups."grafana.admins" = {};
      groups."grafana.server-admins" = {};

      # --- Forgejo ---
      groups."forgejo.access" = {};
      groups."forgejo.admins" = {};

      # --- Paperless (DEAKTIVIERT - keine aktive MicroVM) ---
      # groups."paperless.access" = {};

      # --- Immich (DEAKTIVIERT - keine aktive MicroVM) ---
      # groups."immich.access" = {};

      # --- Linkwarden (DEAKTIVIERT - keine aktive MicroVM) ---
      # groups."linkwarden.access" = {};
      # groups."linkwarden.admins" = {};

      # --- Open-WebUI (DEAKTIVIERT - keine aktive MicroVM) ---
      # groups."open-webui.access" = {};

      # --- Web-Sentinel (oauth2-proxy auf PAZ-PROXY-01) ---
      # Dieser Client schützt Services die KEINE eigene OAuth2-Integration haben
      # (z.B. edu-search, adguardhome). Zugang wird über Untergruppen gesteuert.
      groups."web-sentinel.access" = {};
      groups."web-sentinel.edu-search" = {};
      groups."web-sentinel.adguardhome" = {};
      # Deaktiviert: open-webui hat keine aktive MicroVM
      # groups."web-sentinel.open-webui" = {};

      # =====================================================================
      # OAuth2/OIDC Clients
      # =====================================================================

      # --- Edu-Search ---
      # edu-search hat KEINE eigene OAuth2-Integration (statische SPA + MeiliSearch).
      # Authentifizierung läuft über web-sentinel (oauth2-proxy auf PAZ-PROXY-01).
      # → Kein eigener OAuth2-Client nötig, wird über web-sentinel.edu-search Gruppe gesteuert.

      # --- Grafana (eigene OAuth2-Integration) ---
      systems.oauth2.grafana = lib.mkIf (hasOAuth2Secret "grafana") {
        displayName = "Grafana";
        originUrl = "https://${globals.services.grafana.domain}/login/generic_oauth";
        originLanding = "https://${globals.services.grafana.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-grafana.path;
        preferShortUsername = true;
        scopeMaps."grafana.access" = ["openid" "email" "profile"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup = {
            "grafana.editors" = ["editor"];
            "grafana.admins" = ["admin"];
            "grafana.server-admins" = ["server_admin"];
          };
        };
      };

      # --- Forgejo (eigene OAuth2-Integration) ---
      systems.oauth2.forgejo = lib.mkIf (hasOAuth2Secret "forgejo") {
        displayName = "Forgejo";
        originUrl = "https://${globals.services.forgejo.domain}/user/oauth2/kanidm/callback";
        originLanding = "https://${globals.services.forgejo.domain}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-forgejo.path;
        preferShortUsername = true;
        # PKCE wird von Forgejo noch nicht unterstützt
        # https://github.com/go-gitea/gitea/issues/21376
        allowInsecureClientDisablePkce = true;
        scopeMaps."forgejo.access" = ["openid" "email" "profile"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup."forgejo.admins" = ["admin"];
        };
      };

      # --- Paperless (DEAKTIVIERT - keine aktive MicroVM) ---
      # systems.oauth2.paperless = lib.mkIf (hasOAuth2Secret "paperless") {
      #   displayName = "Paperless";
      #   originUrl = "https://${globals.services.paperless.domain}/accounts/oidc/kanidm/login/callback/";
      #   originLanding = "https://${globals.services.paperless.domain}/";
      #   basicSecretFile = config.age.secrets.kanidm-oauth2-paperless.path;
      #   preferShortUsername = true;
      #   scopeMaps."paperless.access" = ["openid" "email" "profile"];
      # };

      # --- Immich (DEAKTIVIERT - keine aktive MicroVM) ---
      # systems.oauth2.immich = lib.mkIf (hasOAuth2Secret "immich") {
      #   displayName = "Immich";
      #   originUrl = [
      #     "https://${globals.services.immich.domain}/auth/login"
      #     "https://${globals.services.immich.domain}/api/oauth/mobile-redirect"
      #   ];
      #   originLanding = "https://${globals.services.immich.domain}/";
      #   basicSecretFile = config.age.secrets.kanidm-oauth2-immich.path;
      #   preferShortUsername = true;
      #   scopeMaps."immich.access" = ["openid" "email" "profile"];
      # };

      # --- Linkwarden (DEAKTIVIERT - keine aktive MicroVM) ---
      # systems.oauth2.linkwarden = lib.mkIf (hasOAuth2Secret "linkwarden") {
      #   displayName = "Linkwarden";
      #   originUrl = "https://${globals.services.linkwarden.domain}/api/v1/auth/callback/authentik";
      #   originLanding = "https://${globals.services.linkwarden.domain}/";
      #   basicSecretFile = config.age.secrets.kanidm-oauth2-linkwarden.path;
      #   preferShortUsername = true;
      #   # ES256 nicht unterstützt, daher Legacy-Crypto
      #   enableLegacyCrypto = true;
      #   scopeMaps."linkwarden.access" = ["openid" "email" "profile"];
      # };

      # --- Web-Sentinel (oauth2-proxy auf PAZ-PROXY-01) ---
      # Schützt Services OHNE eigene OAuth2-Integration:
      #   edu-search, adguardhome, open-webui
      # Zugriff wird über Untergruppen gesteuert:
      #   web-sentinel.edu-search → Zugang zu edu.czichy.com
      #   web-sentinel.adguardhome → Zugang zu dns.czichy.com
      #   web-sentinel.open-webui → Zugang zu chat.czichy.com
      systems.oauth2.web-sentinel = lib.mkIf (hasOAuth2Secret "web-sentinel") {
        displayName = "Web Sentinel";
        originUrl = "https://oauth2.${globals.domains.me}/oauth2/callback";
        originLanding = "https://oauth2.${globals.domains.me}/";
        basicSecretFile = config.age.secrets.kanidm-oauth2-web-sentinel.path;
        preferShortUsername = true;
        scopeMaps."web-sentinel.access" = ["openid" "email"];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup = {
            "web-sentinel.edu-search" = ["access_edu_search"];
            "web-sentinel.adguardhome" = ["access_adguardhome"];
            # Deaktiviert: open-webui hat keine aktive MicroVM
            # "web-sentinel.open-webui" = ["access_openwebui"];
          };
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Systemd-Anpassungen
  # ---------------------------------------------------------------------------
  systemd.services.kanidm = lib.mkIf hasRequiredSecrets {
    serviceConfig.RestartSec = "60"; # Bei Fehler 60s warten
    environment.KANIDM_TRUST_X_FORWARD_FOR = "true";
  };

  # ---------------------------------------------------------------------------
  # Restic Backup → rclone (OneDrive NAS)
  # ---------------------------------------------------------------------------
  # Kanidm's online_backup erstellt täglich konsistente JSON-Dumps unter
  # backupDir. Restic sichert diese Dumps anschließend offsite via rclone.
  #
  #   Zeitplan:
  #     02:00  Kanidm online_backup (→ /var/lib/kanidm/backups/)
  #     02:30  Restic sichert die Dumps nach OneDrive
  #
  #   Secret anlegen:
  #     openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/restic-kanidm.age
  # ---------------------------------------------------------------------------
  services.restic.backups = lib.mkIf (hasRequiredSecrets && hasBackupSecrets) (let
    ntfy_pass = lib.optionalString hasNtfy "$(cat ${config.age.secrets.kanidm-ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";

    script-post = host: site: ''
      if [ $EXIT_STATUS -ne 0 ]; then
        ${lib.optionalString hasNtfy ''
          ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} failed!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ''}
        echo "ERROR: Restic backup ${site} on ${host} failed (exit $EXIT_STATUS)" >&2
      else
        ${lib.optionalString hasNtfy ''
          ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} OK' \
            -H 'Tags: backup,restic,${host},${site},white_check_mark' \
            -H 'Priority: low' \
            -d "Restic (${site}) backup on ${host} completed successfully." '${ntfy_url}'
        ''}
        echo "Restic backup ${site} on ${host} completed successfully."
      fi
    '';
  in {
    kanidm-backup = {
      # Repository bei erstem Lauf automatisch initialisieren
      initialize = true;

      # Ziel: rclone-Remote (OneDrive NAS)
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-kanidm";

      # Kanidm online_backup JSON-Dumps sichern
      paths = [backupDir];

      exclude = [];

      passwordFile = config.age.secrets.restic-kanidm.path;
      rcloneConfigFile = config.age.secrets."rclone-kanidm.conf".path;

      # Cleanup-Script: ntfy-Benachrichtigung nach Backup
      backupCleanupCommand = script-post config.networking.hostName "kanidm";

      # Aufbewahrungsrichtlinie: 14 Snapshots behalten, Rest prunen
      pruneOpts = ["--keep-last 14"];

      # Zeitplan: 30 Min nach online_backup (02:00), damit Dump fertig ist
      timerConfig = {
        OnCalendar = "*-*-* 02:30:00";
        # Verpasste Backups nachholen (z.B. nach Shutdown)
        Persistent = true;
        # Leichte Streuung um Lastspitzen zu vermeiden
        RandomizedDelaySec = "5min";
      };
    };
  });

  # ---------------------------------------------------------------------------
  # Boot / Netzwerk
  # ---------------------------------------------------------------------------
  # Hinweis: HOST-02 stellt kein /state ZFS-Dataset bereit (anders als HOST-01).
  # Kanidm nutzt /persist (via virtiofs aus common-guest-config) für Persistenz.

  systemd.network.enable = true;
  system.stateVersion = "24.05";

  # ---------------------------------------------------------------------------
  # Warnung wenn Secrets fehlen
  # ---------------------------------------------------------------------------
  warnings =
    lib.optional (!hasRequiredSecrets) (
      "kanidm: Nicht alle TLS/Admin-Secrets vorhanden - Kanidm-Server ist DEAKTIVIERT.\n"
      + "Benoetigte Secrets (siehe Kommentar am Dateianfang fuer Anleitung):\n"
      + (lib.optionalString (!hasTlsCrt) "  - hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.crt.age\n")
      + (lib.optionalString (!hasTlsKey) "  - hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.key.age\n")
      + (lib.optionalString (!hasAdminPw) "  - hosts/HL-1-MRZ-HOST-02/guests/kanidm/admin-password.age\n")
      + (lib.optionalString (!hasIdmAdminPw) "  - hosts/HL-1-MRZ-HOST-02/guests/kanidm/idm-admin-password.age\n")
    )
    ++ lib.optional (hasRequiredSecrets && !hasBackupSecrets) (
      "kanidm: Backup-Secrets fehlen - Restic-Backup ist DEAKTIVIERT.\n"
      + "Benoetigte Secrets:\n"
      + (lib.optionalString (!hasRestic) "  - hosts/HL-1-MRZ-HOST-02/guests/kanidm/restic-kanidm.age\n")
      + (lib.optionalString (!hasRclone) "  - rclone/onedrive_nas/rclone.conf.age\n")
    );
}
