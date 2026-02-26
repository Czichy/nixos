# Radicale CalDAV/CardDAV Server – Kalender & Kontakte
#
# Radicale läuft als MicroVM auf HOST-02 und bietet:
# - CalDAV (Kalender) für Thunderbird, iOS, Android
# - CardDAV (Kontakte) für Thunderbird, iOS, Android
# - Web-Interface für einfache Verwaltung
# - htpasswd-Authentifizierung (bcrypt)
#
# Authentifizierung:
#   Radicale nutzt htpasswd (bcrypt) statt OAuth2/Kanidm, weil CalDAV/CardDAV-
#   Clients (Thunderbird, iOS, Android) HTTP Basic Auth senden.
#   OAuth2 ist mit CalDAV nicht kompatibel.
#
# Thunderbird-Einrichtung:
#   1. Thunderbird öffnen → Einstellungen → Kalender
#   2. "Neuer Kalender" → "Im Netzwerk"
#   3. Format: CalDAV
#      URL: https://cal.czichy.com/christian/calendar.ics/
#      (Ersetze "christian" durch deinen Benutzernamen)
#   4. Benutzername + Passwort aus dem htpasswd-Secret eingeben
#
#   Für Kontakte (CardDAV):
#   1. Add-on "CardBook" installieren (oder TbSync + Provider für CalDAV & CardDAV)
#   2. Neues Adressbuch → CardDAV
#      URL: https://cal.czichy.com/christian/contacts.vcf/
#   3. Benutzername + Passwort eingeben
#
#   Automatische Erkennung (empfohlen):
#   Thunderbird kann Collections automatisch finden:
#      URL: https://cal.czichy.com/christian/
#      → Thunderbird listet alle Kalender und Adressbücher auf
#
# Secrets erstellen (im private-Repo):
#   # htpasswd-Datei mit bcrypt-Hashes:
#   htpasswd -Bc /tmp/radicale-users christian
#   htpasswd -B /tmp/radicale-users ina
#   agenix -e hosts/HL-1-MRZ-HOST-02/guests/radicale/radicale-users.age < /tmp/radicale-users
#   rm /tmp/radicale-users
#
#   # Restic-Backup-Passwort:
#   openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/radicale/restic-radicale.age
#
# Nützliche Befehle:
#   # Radicale-Status prüfen:
#   systemctl status radicale
#
#   # Backup manuell auslösen:
#   systemctl start restic-backups-radicale-backup.service
#
#   # Logs anzeigen:
#   journalctl -u radicale -f
{
  config,
  globals,
  secretsPath,
  pkgs,
  lib,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Konfiguration
  # ---------------------------------------------------------------------------
  radicaleDomain = "cal.${globals.domains.me}";
  radicalePort = 5232;
  certloc = "/var/lib/acme-sync/czichy.com";

  # ---------------------------------------------------------------------------
  # Secret-Pfade & Existenz-Prüfungen
  # ---------------------------------------------------------------------------
  secretsBase = secretsPath + "/hosts/HL-1-MRZ-HOST-02/guests/radicale";

  htpasswdFile = secretsBase + "/radicale-users.age";
  resticFile = secretsBase + "/restic-radicale.age";
  rcloneFile = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
  ntfyFile = secretsPath + "/ntfy-sh/alert-pass.age";
  hcPingFile = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";

  hasHtpasswd = builtins.pathExists htpasswdFile;
  hasRestic = builtins.pathExists resticFile;
  hasRclone = builtins.pathExists rcloneFile;
  hasNtfy = builtins.pathExists ntfyFile;
  hasHcPing = builtins.pathExists hcPingFile;
  hasBackupSecrets = hasRestic && hasRclone;
in {
  # ---------------------------------------------------------------------------
  # MicroVM-Ressourcen
  # ---------------------------------------------------------------------------
  # Radicale ist extrem leichtgewichtig: Python-basiert, ~30MB RAM.
  # 512MB RAM + 1 vCPU reichen locker.
  microvm.mem = 512;
  microvm.vcpu = 1;

  networking.hostName = "HL-3-RZ-CAL-01";

  # ---------------------------------------------------------------------------
  # Agenix Secrets
  # ---------------------------------------------------------------------------
  age.secrets.radicale-users = lib.mkIf hasHtpasswd {
    file = htpasswdFile;
    mode = "440";
    group = "radicale";
  };

  age.secrets.restic-radicale = lib.mkIf hasRestic {
    file = resticFile;
    mode = "440";
  };

  age.secrets."rclone.conf" = lib.mkIf hasRclone {
    file = rcloneFile;
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = lib.mkIf hasNtfy {
    file = ntfyFile;
    mode = "440";
  };

  age.secrets.radicale-hc-ping = lib.mkIf hasHcPing {
    file = hcPingFile;
    mode = "440";
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [
    radicalePort # Radicale (CalDAV/CardDAV + Web-UI)
  ];

  # ---------------------------------------------------------------------------
  # Radicale Service
  # ---------------------------------------------------------------------------
  services.radicale = {
    enable = true;

    settings = {
      server = {
        hosts = [
          "0.0.0.0:${toString radicalePort}"
          "[::]:${toString radicalePort}"
        ];
        # Maximale Anzahl paralleler Verbindungen
        max_connections = 20;
        # Timeout in Sekunden
        timeout = 30;
      };

      auth = {
        type = "htpasswd";
        htpasswd_filename =
          if hasHtpasswd
          then config.age.secrets.radicale-users.path
          else "/dev/null";
        htpasswd_encryption = "bcrypt";
      };

      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
      };

      # Logging
      logging = {
        level = "info";
        # Maske für sensible Daten in Logs
        mask_passwords = true;
      };

      # Web-Interface aktivieren (für einfache Verwaltung im Browser)
      web = {
        type = "internal";
      };
    };

    # -------------------------------------------------------------------------
    # Zugriffsrechte (ACL)
    # -------------------------------------------------------------------------
    # Jeder Benutzer darf nur auf seine eigenen Collections zugreifen.
    # Die Rechte werden von oben nach unten geprüft – erste Übereinstimmung gilt.
    rights = {
      # Root-Collection: Jeder authentifizierte Benutzer darf lesen
      # (nötig für CalDAV/CardDAV Service-Discovery)
      root = {
        user = ".+";
        collection = "";
        permissions = "R";
      };

      # Principal-Collection: Jeder Benutzer darf seine eigene verwalten
      # (z.B. /christian/ für Benutzer "christian")
      principal = {
        user = ".+";
        collection = "{user}";
        permissions = "RW";
      };

      # Kalender und Adressbücher: Lesen + Schreiben auf eigene Collections
      # (z.B. /christian/calendar.ics/, /christian/contacts.vcf/)
      calendars = {
        user = ".+";
        collection = "{user}/[^/]+";
        permissions = "rw";
      };
    };
  };

  # Restart-Verhalten
  systemd.services.radicale.serviceConfig.RestartSec = "60";

  # ---------------------------------------------------------------------------
  # Impermanence
  # ---------------------------------------------------------------------------
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/var/lib/radicale";
        user = "radicale";
        group = "radicale";
        mode = "0700";
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Service-Registrierung in globals (Homepage, Monitoring)
  # ---------------------------------------------------------------------------
  globals.services.radicale = {
    domain = radicaleDomain;
    homepage = {
      enable = true;
      name = "Radicale";
      icon = "sh-radicale";
      description = "CalDAV/CardDAV – Kalender & Kontakte (Thunderbird, iOS)";
      category = "Documents & Notes";
      requiresAuth = true;
      priority = 30;
      abbr = "CAL";
    };
  };

  globals.monitoring.http.radicale = {
    url = "http://${globals.net.vlan40.hosts."HL-3-RZ-CAL-01".ipv4}:${toString radicalePort}/.web/";
    expectedBodyRegex = "Radicale";
    network = "vlan40";
  };

  # ---------------------------------------------------------------------------
  # Reverse Proxy: Caddy
  # ---------------------------------------------------------------------------

  # Interner Caddy auf HOST-02 (vlan40 → MicroVM)
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${radicaleDomain}".extraConfig = ''
        # RFC 6764: Well-Known URLs für CalDAV/CardDAV Auto-Discovery
        # Thunderbird, iOS, Android finden den Server automatisch über:
        #   https://cal.czichy.com/.well-known/caldav
        #   https://cal.czichy.com/.well-known/carddav
        redir /.well-known/caldav / 301
        redir /.well-known/carddav / 301

        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-CAL-01".ipv4}:${toString radicalePort} {
          # CalDAV/CardDAV Clients senden teils große vCards/vCals
          transport http {
            read_buffer 16384
          }
        }
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
        # CalDAV/CardDAV braucht größere Body-Limits
        request_body {
          max_size 16MB
        }
      '';
    };
  };

  # Externer Caddy auf PAZ-PROXY-01 (Internet → interner Caddy)
  # KEIN oauth2-proxy hier! CalDAV/CardDAV-Clients (Thunderbird, iOS, Android)
  # authentifizieren sich direkt mit HTTP Basic Auth gegen Radicale's htpasswd.
  # oauth2-proxy würde die CalDAV/CardDAV-Protokoll-Kommunikation brechen.
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${radicaleDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
          transport http {
            tls_insecure_skip_verify
            tls_server_name ${radicaleDomain}
          }
        }
        import czichy_headers
        # CalDAV/CardDAV braucht größere Body-Limits
        request_body {
          max_size 16MB
        }
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Restic-Backup
  # ---------------------------------------------------------------------------
  # Radicale-Daten sind wichtig (Kalender, Kontakte) und nicht rekonstruierbar.
  # Backup nach OneDrive via rclone.
  services.restic.backups = lib.mkIf hasBackupSecrets (let
    ntfy_pass =
      if hasNtfy
      then "$(cat ${config.age.secrets.ntfy-alert-pass.path})"
      else "";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      ${lib.optionalString hasHcPing ''
        pingKey="$(cat ${config.age.secrets.radicale-hc-ping.path})"
      ''}
      if [ $EXIT_STATUS -ne 0 ]; then
        ${lib.optionalString hasNtfy ''
          ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
            -H 'Title: Backup (${site}) on ${host} failed!' \
            -H 'Tags: backup,restic,${host},${site}' \
            -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ''}
        ${lib.optionalString hasHcPing ''
          ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}/fail"
        ''}
      else
        ${lib.optionalString hasHcPing ''
          ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}"
        ''}
      fi
    '';
  in {
    radicale-backup = {
      initialize = true;

      # Backup nach OneDrive via rclone
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-radicale";

      # Was wird gesichert: Alle Radicale-Collections (Kalender + Kontakte)
      paths = [
        "/var/lib/radicale"
      ];

      exclude = [
        "/var/lib/radicale/.Radicale.lock"
      ];

      passwordFile = config.age.secrets.restic-radicale.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # Benachrichtigung + Healthcheck nach Backup
      backupCleanupCommand = script-post config.networking.hostName "radicale";

      # Aufbewahrung: Radicale-Daten ändern sich häufig (Kalender-Einträge),
      # daher moderate Retention.
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 6"
      ];

      # Täglich um 02:30 Uhr
      timerConfig = {
        OnCalendar = "*-*-* 02:30:00";
        Persistent = true;
        RandomizedDelaySec = "30min";
      };
    };
  });

  # ---------------------------------------------------------------------------
  # Nützliche Pakete
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # htpasswd für lokale Benutzerverwaltung
    apacheHttpd # enthält htpasswd
  ];

  # ---------------------------------------------------------------------------
  # Warnungen bei fehlenden Secrets
  # ---------------------------------------------------------------------------
  warnings = let
    missing =
      (lib.optional (!hasHtpasswd) "hosts/HL-1-MRZ-HOST-02/guests/radicale/radicale-users.age")
      ++ (lib.optional (!hasRestic) "hosts/HL-1-MRZ-HOST-02/guests/radicale/restic-radicale.age")
      ++ (lib.optional (!hasRclone) "rclone/onedrive_nas/rclone.conf.age")
      ++ (lib.optional (!hasNtfy) "ntfy-sh/alert-pass.age")
      ++ (lib.optional (!hasHcPing) "hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age");
  in
    (lib.optional (!hasHtpasswd)
      "radicale: htpasswd-Secret fehlt! Radicale akzeptiert KEINE Logins. Erstelle: agenix -e hosts/HL-1-MRZ-HOST-02/guests/radicale/radicale-users.age")
    ++ (lib.optional (!hasBackupSecrets)
      "radicale: Restic-Backup ist DEAKTIVIERT (fehlende Secrets: ${lib.concatStringsSep ", " missing})");

  # ---------------------------------------------------------------------------
  # Netzwerk
  # ---------------------------------------------------------------------------
  # KEIN fileSystems."/state" – HOST-02 MicroVMs nutzen nur /persist
  # (bereitgestellt via virtiofs in common-guest-config.nix).
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
