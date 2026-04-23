# Restic-Backup für Edu-Search (PostgreSQL Metadaten + Indexer State)
#
# Backup-Strategie:
# 1. pg_dump (bereits in postgresql.nix definiert) sichert die Datenbank nach
#    /var/lib/edu-search-backup/edu_search.pgdump
# 2. Restic sichert diesen Dump + Indexer-State nach OneDrive via rclone
# 3. Bei Fehler: ntfy-Benachrichtigung + healthchecks.io Fail-Ping
# 4. Bei Erfolg: healthchecks.io Success-Ping
#
# Was wird gesichert:
# ✅ PostgreSQL Dump (KI-Klassifikationen, Metadaten – nicht rekonstruierbar)
# ✅ Indexer State (state.json – optional, Re-Index jederzeit möglich)
# ❌ MeiliSearch-Index (kann aus PostgreSQL + NAS rebuilt werden)
# ❌ Tika (stateless)
# ❌ Web-UI (im Nix-Store / Git)
# ❌ NAS-Dateien (bereits durch Samba-Backup abgedeckt)
#
# Restore-Anleitung:
#   1. restic restore latest --target /tmp/restore
#   2. pg_restore -U postgres -d edu_search /tmp/restore/var/lib/edu-search-backup/edu_search.pgdump
#   3. systemctl restart edu-indexer  (rebuildet MeiliSearch aus PostgreSQL)
#
# HINWEIS: Alle agenix-Secrets sind mit builtins.pathExists abgesichert.
# Wenn die .age-Dateien im private-Repo noch nicht existieren (vor dem ersten
# Deploy), wird die Backup-Konfiguration übersprungen und der Build schlägt
# NICHT fehl.
#
# Benötigte Secrets (im private-Repo anlegen):
#   agenix -e hosts/HL-1-MRZ-HOST-01/guests/edu-search/restic-edu-search.age
#     → Inhalt: beliebiges Restic-Repository-Passwort (z.B. openssl rand -base64 32)
#   rclone/onedrive_nas/rclone.conf.age           → sollte bereits existieren
#   ntfy-sh/alert-pass.age                        → sollte bereits existieren
#   hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age → sollte bereits existieren
{
  config,
  globals,
  lib,
  secretsPath,
  pkgs,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Secret-Pfade und Existenz-Prüfungen
  # ---------------------------------------------------------------------------
  resticSecretFile = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/edu-search/restic-edu-search.age";
  rcloneSecretFile = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
  ntfySecretFile = secretsPath + "/ntfy-sh/alert-pass.age";
  hcPingSecretFile = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";

  hetznerKeyFile = secretsPath + "/hetzner/storage-box/ssh_key.age";

  hasResticSecret = builtins.pathExists resticSecretFile;
  hasRcloneSecret = builtins.pathExists rcloneSecretFile;
  hasNtfySecret = builtins.pathExists ntfySecretFile;
  hasHcPingSecret = builtins.pathExists hcPingSecretFile;
  hasHetznerKey = builtins.pathExists hetznerKeyFile;

  # Backup ist nur aktiv wenn ALLE benötigten Secrets vorhanden sind
  backupEnabled = hasResticSecret && hasRcloneSecret && hasNtfySecret && hasHcPingSecret;
in {
  # ---------------------------------------------------------------------------
  # Agenix Secrets (nur definiert wenn die .age-Dateien existieren)
  # ---------------------------------------------------------------------------

  # rclone-Konfiguration für OneDrive-Zugriff (gemeinsames Secret)
  age.secrets."rclone.conf" = lib.mkIf hasRcloneSecret {
    file = rcloneSecretFile;
    mode = "440";
  };

  # Restic-Repository-Passwort (eigenes Secret pro Guest)
  age.secrets.restic-edu-search = lib.mkIf hasResticSecret {
    file = resticSecretFile;
    mode = "440";
  };

  # ntfy-Passwort für Fehlerbenachrichtigungen
  age.secrets.ntfy-alert-pass = lib.mkIf hasNtfySecret {
    file = ntfySecretFile;
    mode = "440";
  };

  # Healthchecks.io Ping-Key für Backup-Monitoring
  age.secrets.edu-search-hc-ping = lib.mkIf hasHcPingSecret {
    file = hcPingSecretFile;
    mode = "440";
  };
  age.secrets.hetzner-storage-box-ssh-key = lib.mkIf hasHetznerKey {
    file = hetznerKeyFile;
    mode = "400";
  };

  # ---------------------------------------------------------------------------
  # Restic Backup Service (nur wenn alle Secrets vorhanden)
  # ---------------------------------------------------------------------------
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = lib.mkIf backupEnabled (let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.edu-search-hc-ping.path})"
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
    edu-search-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # Backup to OneDrive via rclone
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-edu-search";

      # Which local paths to backup.
      paths = [
        # PostgreSQL Dump (erstellt von edu-search-pg-dump.service in postgresql.nix)
        "/var/lib/edu-search-backup"
        # Indexer-Status (optional – Re-Index jederzeit möglich)
        "/var/lib/edu-indexer"
      ];

      # Patterns to exclude when backing up.
      exclude = [
        # Temporäre pg_dump-Dateien
        "/var/lib/edu-search-backup/*.tmp"
        # Python __pycache__
        "/var/lib/edu-indexer/__pycache__"
      ];

      passwordFile = config.age.secrets.restic-edu-search.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # pg_dump MUSS vor dem Backup laufen, damit ein aktueller Dump vorliegt.
      # Der Service ist in postgresql.nix definiert.
      backupPrepareCommand = ''
        echo "Running pg_dump before backup..."
        systemctl start edu-search-pg-dump.service
        echo "pg_dump completed."
      '';

      # Benachrichtigung + Healthcheck nach Backup (Erfolg oder Fehler)
      backupCleanupCommand = script-post config.networking.hostName "edu-search";

      # Prune old snapshots – Edu-Search-Daten ändern sich selten,
      # daher konservativere Retention als bei z.B. Forgejo.
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 2"
      ];

      timerConfig = {
        OnCalendar = "*-*-* 02:30:00";
        RandomizedDelaySec = "15min";
        Persistent = true;
      };
    };
  }
  // lib.optionalAttrs hasHetznerKey {
    edu-search-backup-hetzner = {
      initialize = true;
      repository = "sftp:u581144@u581144.your-storagebox.de:/restic/${config.networking.hostName}-edu-search";
      paths = [
        "/var/lib/edu-search-backup"
        "/var/lib/edu-indexer"
      ];
      exclude = [
        "/var/lib/edu-search-backup/*.tmp"
        "/var/lib/edu-indexer/__pycache__"
      ];
      passwordFile = config.age.secrets.restic-edu-search.path;
      extraOptions = [
        "sftp.args='-i ${config.age.secrets.hetzner-storage-box-ssh-key.path} -o StrictHostKeyChecking=accept-new'"
      ];
      backupPrepareCommand = ''
        echo "Running pg_dump before Hetzner backup..."
        systemctl start edu-search-pg-dump.service
        echo "pg_dump completed."
      '';
      backupCleanupCommand = script-post config.networking.hostName "edu-search-hetzner";
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 2"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 03:30:00";
        Persistent = true;
      };
    };
  });

  # ---------------------------------------------------------------------------
  # Warnung wenn Secrets fehlen
  # ---------------------------------------------------------------------------
  warnings = let
    missing =
      (lib.optional (!hasResticSecret) "hosts/HL-1-MRZ-HOST-01/guests/edu-search/restic-edu-search.age")
      ++ (lib.optional (!hasRcloneSecret) "rclone/onedrive_nas/rclone.conf.age")
      ++ (lib.optional (!hasNtfySecret) "ntfy-sh/alert-pass.age")
      ++ (lib.optional (!hasHcPingSecret) "hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age");
  in
    lib.optional (!backupEnabled)
      "edu-search backup: Restic-Backup ist DEAKTIVIERT (fehlende Secrets: ${lib.concatStringsSep ", " missing})";

  # ---------------------------------------------------------------------------
  # Monitoring: Backup-Status
  # ---------------------------------------------------------------------------
  # Healthchecks.io überwacht, ob das Backup regelmäßig läuft.
  # Bei Ausbleiben des Pings wird automatisch eine Warnung gesendet.
  # Konfiguration in healthchecks.io:
  #   Name: backup-edu-search
  #   Period: 1 day
  #   Grace: 6 hours

  # |----------------------------------------------------------------------| #
  tensorfiles.services.resticMaintenance = lib.mkIf backupEnabled {
    enable = true;
    ntfyPassFile = config.age.secrets.ntfy-alert-pass.path;
  };
}
