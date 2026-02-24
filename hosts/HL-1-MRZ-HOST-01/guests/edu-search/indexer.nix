# Python-basierter Edu-Search Indexer Service
#
# Kernkomponente der Edu-Search Pipeline:
# 1. Überwacht NAS-Verzeichnisse auf neue/geänderte/gelöschte Dateien (Watchdog)
# 2. Extrahiert Text via Apache Tika HTTP API (lokal in der MicroVM)
# 3. Klassifiziert via Ollama LLM auf HOST-01 (GPU-beschleunigt)
# 4. Speichert Metadaten in PostgreSQL (lokal in der MicroVM)
# 5. Indexiert in MeiliSearch für die Web-Suche (lokal in der MicroVM)
#
# Der Service läuft als Daemon mit einem PollingObserver (wegen virtiofs,
# das nicht zuverlässig inotify-Events sendet).
#
# Alle NAS-Shares werden READ-ONLY gemountet. Originaldateien werden
# NIEMALS verändert.
{
  pkgs,
  globals,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Konfiguration
  # ---------------------------------------------------------------------------
  ollamaHost = globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4;
  ollamaPort = 11434;
  ollamaUrl = "http://${ollamaHost}:${toString ollamaPort}";
  ollamaModel = "mistral:7b";

  tikaUrl = "http://127.0.0.1:9998";
  meiliUrl = "http://127.0.0.1:7700";
  meiliIndex = "edu_documents";

  dbHost = "127.0.0.1";
  dbPort = "5432";
  dbName = "edu_search";
  dbUser = "edu_indexer";

  # Alle zu überwachenden NAS-Verzeichnisse (virtiofs-Mounts in der MicroVM)
  watchDirs = "/nas/ina/schule,/nas/bibliothek,/nas/dokumente";

  # SMB-Basis-URL für die Web-UI Links
  # Ina klickt in der Suche auf ein Ergebnis → öffnet die Datei via SMB
  smbBase = "smb://HL-3-RZ-SMB-01";

  # Polling-Interval in Sekunden
  # virtiofs sendet nicht zuverlässig inotify-Events, daher Polling
  pollInterval = "60";

  # MeiliSearch Master-Key wird zur Laufzeit aus /run/edu-search/meili-master-key gelesen.
  # Die Datei wird von edu-search-meili-key.service (meilisearch.nix) bereitgestellt.
  meiliKeyFile = "/run/edu-search/meili-master-key";

  # ---------------------------------------------------------------------------
  # Python-Umgebung mit allen Abhängigkeiten
  # ---------------------------------------------------------------------------
  pythonEnv = pkgs.python3.withPackages (ps:
    with ps; [
      watchdog    # Dateisystem-Überwachung (PollingObserver)
      requests    # HTTP-Client für Tika + Ollama APIs
      psycopg2    # PostgreSQL-Client
      meilisearch # MeiliSearch Python Client (PyPI: meilisearch)
    ]);

  # ---------------------------------------------------------------------------
  # Pfad zum Indexer-Skript (wird im Nix-Store abgelegt)
  # ---------------------------------------------------------------------------
  indexerScript = ./indexer.py;

in {
  # ---------------------------------------------------------------------------
  # System-User für den Indexer
  # ---------------------------------------------------------------------------
  users.users.edu-indexer = {
    isSystemUser = true;
    group = "users";
    home = "/var/lib/edu-indexer";
    createHome = true;
    description = "Edu-Search document indexer service user";
  };

  # ---------------------------------------------------------------------------
  # Haupt-Service: Edu-Search Indexer Daemon
  # ---------------------------------------------------------------------------
  systemd.services.edu-indexer = {
    description = "Edu-Search Document Indexer (Tika + Ollama + MeiliSearch)";
    documentation = ["file:///etc/nixos/PLAN_EDU_SEARCH.md"];

    # Abhängigkeiten: Alle Backend-Services müssen laufen
    after = [
      "network-online.target"
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
      "edu-search-meili-key.service"
    ];
    requires = [
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
    ];
    wants = ["network-online.target" "edu-search-meili-key.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "30s";

      # Als eigener User laufen (nicht root)
      User = "edu-indexer";
      Group = "users";

      # Python-Skript ausführen
      ExecStart = "${pythonEnv}/bin/python ${indexerScript}";

      # Warte bis die Abhängigkeiten wirklich bereit sind
      ExecStartPre = let
        waitScript = pkgs.writeShellScript "edu-indexer-wait" ''
          set -euo pipefail
          echo "Warte auf Backend-Services..."

          # Warte auf PostgreSQL
          for i in $(seq 1 30); do
            if ${pkgs.postgresql_16}/bin/pg_isready -h ${dbHost} -p ${dbPort} -U ${dbUser} -d ${dbName} > /dev/null 2>&1; then
              echo "  PostgreSQL: bereit"
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "  PostgreSQL: TIMEOUT nach 30s" >&2
              exit 1
            fi
            sleep 1
          done

          # Warte auf Tika
          for i in $(seq 1 30); do
            if ${pkgs.curl}/bin/curl -sf "${tikaUrl}/tika" > /dev/null 2>&1; then
              echo "  Tika: bereit"
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "  Tika: TIMEOUT nach 30s" >&2
              exit 1
            fi
            sleep 1
          done

          # Warte auf MeiliSearch
          for i in $(seq 1 30); do
            if ${pkgs.curl}/bin/curl -sf "${meiliUrl}/health" > /dev/null 2>&1; then
              echo "  MeiliSearch: bereit"
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "  MeiliSearch: TIMEOUT nach 30s" >&2
              exit 1
            fi
            sleep 1
          done

          # Ollama auf HOST-01 ist optional beim Start – der Indexer
          # handelt Timeouts selbst und markiert Dateien als "pending"
          if ${pkgs.curl}/bin/curl -sf "${ollamaUrl}" > /dev/null 2>&1; then
            echo "  Ollama: bereit"
          else
            echo "  Ollama: nicht erreichbar (wird beim Indexieren erneut versucht)"
          fi

          echo "Alle lokalen Backend-Services bereit. Starte Indexer..."
        '';
      in "${waitScript}";

      # Umgebungsvariablen für das Python-Skript
      Environment = [
        "OLLAMA_URL=${ollamaUrl}"
        "OLLAMA_MODEL=${ollamaModel}"
        "TIKA_URL=${tikaUrl}"
        "MEILI_URL=${meiliUrl}"
        "MEILI_INDEX=${meiliIndex}"
        "MEILI_KEY_FILE=${meiliKeyFile}"
        "WATCH_DIRS=${watchDirs}"
        "SMB_BASE=${smbBase}"
        "DB_HOST=${dbHost}"
        "DB_PORT=${dbPort}"
        "DB_NAME=${dbName}"
        "DB_USER=${dbUser}"
        "STATE_FILE=/var/lib/edu-indexer/state.json"
        "POLL_INTERVAL=${pollInterval}"
        # Python: ungepuffertes stdout/stderr für sofortige Log-Ausgabe
        "PYTHONUNBUFFERED=1"
      ];

      # -----------------------------------------------------------------------
      # Sicherheits-Härtung
      # -----------------------------------------------------------------------
      NoNewPrivileges = true;
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";

      # NAS-Shares sind read-only (Originaldateien werden NICHT verändert)
      ReadOnlyPaths = ["/nas"];
      ReadWritePaths = ["/var/lib/edu-indexer"];

      # Ressourcen-Limits
      LimitNOFILE = 4096;
      # OOM-Kill-Priorität: Indexer darf am ehesten gekillt werden
      # (kann jederzeit neu gestartet werden, kein Datenverlust)
      OOMScoreAdjust = 500;

      # Timeout für den Start (initiale Indexierung kann lange dauern)
      TimeoutStartSec = "infinity";
    };
  };

  # ---------------------------------------------------------------------------
  # Oneshot-Service: Vollständige Re-Indexierung (manuell auslösbar)
  # ---------------------------------------------------------------------------
  # Kann manuell gestartet werden um alle Dateien neu zu indexieren:
  #   systemctl start edu-reindex.service
  #
  # Nützlich nach:
  # - Änderung des Ollama-Prompts (bessere Klassifikation)
  # - Wechsel des LLM-Modells
  # - Rebuild von MeiliSearch aus PostgreSQL
  systemd.services.edu-reindex = {
    description = "Edu-Search: Force complete re-indexing of all documents";

    after = [
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
    ];
    requires = [
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
    ];

    # NICHT automatisch starten – nur manuell via systemctl
    # wantedBy wird absichtlich NICHT gesetzt

    serviceConfig = {
      Type = "oneshot";
      User = "edu-indexer";
      Group = "users";

      ExecStart = "${pythonEnv}/bin/python ${indexerScript} --reindex";

      Environment = [
        "OLLAMA_URL=${ollamaUrl}"
        "OLLAMA_MODEL=${ollamaModel}"
        "TIKA_URL=${tikaUrl}"
        "MEILI_URL=${meiliUrl}"
        "MEILI_INDEX=${meiliIndex}"
        "MEILI_KEY_FILE=${meiliKeyFile}"
        "WATCH_DIRS=${watchDirs}"
        "SMB_BASE=${smbBase}"
        "DB_HOST=${dbHost}"
        "DB_PORT=${dbPort}"
        "DB_NAME=${dbName}"
        "DB_USER=${dbUser}"
        "STATE_FILE=/var/lib/edu-indexer/state.json"
        "POLL_INTERVAL=${pollInterval}"
        "PYTHONUNBUFFERED=1"
        # Flag: erzwingt Re-Indexierung aller Dateien (ignoriert Hash-Cache)
        "FORCE_REINDEX=1"
      ];

      ReadOnlyPaths = ["/nas"];
      ReadWritePaths = ["/var/lib/edu-indexer"];

      # Re-Indexierung kann bei vielen Dateien sehr lange dauern
      TimeoutStartSec = "6h";
    };
  };

  # ---------------------------------------------------------------------------
  # Impermanence: Indexer-State persistent machen
  # ---------------------------------------------------------------------------
  # Der state.json enthält den letzten bekannten Zustand der Indexierung.
  # Ist optional – bei Verlust wird einfach alles neu indexiert (dauert nur länger).
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/edu-indexer";
      user = "edu-indexer";
      group = "users";
      mode = "0750";
    }
  ];

  # ---------------------------------------------------------------------------
  # Log-Rotation
  # ---------------------------------------------------------------------------
  # Der Indexer loggt nach stdout/stderr → journald.
  # journald rotiert automatisch, aber wir setzen ein explizites Limit.
  systemd.services.edu-indexer.serviceConfig = {
    StandardOutput = "journal";
    StandardError = "journal";
    SyslogIdentifier = "edu-indexer";
  };
}
