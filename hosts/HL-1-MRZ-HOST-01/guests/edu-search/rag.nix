# Edu-Search RAG API Service
#
# FastAPI-Dienst für KI-gestützte Klausurerstellung und semantische Suche.
#
# Architektur (RAG = Retrieval-Augmented Generation):
#   Nutzeranfrage → Ollama Embedding → pgvector-Suche
#                → MeiliSearch-Suche
#                → Kontext-Aufbau → Ollama LLM → Klausur (SSE Streaming)
#
# Endpunkte (via Nginx auf Port 8080 proxied):
#   GET  /api/rag/health           → Healthcheck
#   POST /api/rag/klausur          → Klausur generieren (SSE)
#   POST /api/rag/search-semantic  → Semantische Ähnlichkeitssuche
#
# n8n-Integration (bereits vorbereitet):
#   n8n (HL-3-RZ-N8N-01) kann via HTTP-Request-Node den /api/rag/klausur-
#   Endpunkt aufrufen. Ergebnis kann als E-Mail, PDF oder Datei ausgegeben
#   werden. Trigger: n8n-Formular-Submission oder Webhook.
#
# HINWEIS: Ollama läuft nativ auf HOST-01 (GPU). Der RAG-Service greift
#          via HTTP auf HOST-01:11434 zu. Kein Ollama in der MicroVM.
{
  globals,
  pkgs,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Konfiguration
  # ---------------------------------------------------------------------------
  ollamaHost = globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4;
  ollamaUrl = "http://${ollamaHost}:11434";

  # Modelle für RAG
  # llama3.1:8b empfohlen für Klausurerstellung (bessere Qualität als mistral:7b)
  # Fallback auf mistral:7b wenn llama3.1 nicht verfügbar
  ollamaModel = "mistral:7b";
  ollamaEmbedModel = "nomic-embed-text";

  meiliUrl = "http://127.0.0.1:7700";
  meiliIndex = "edu_documents";
  meiliKeyFile = "/run/edu-search/meili-master-key";

  dbHost = "127.0.0.1";
  dbPort = "5432";
  dbName = "edu_search";
  dbUser = "edu_indexer";

  # RAG API lauscht nur lokal – Nginx proxied es nach außen
  ragHost = "127.0.0.1";
  ragPort = 8090;

  # ---------------------------------------------------------------------------
  # Python-Umgebung mit FastAPI + Datenbankzugriff
  # ---------------------------------------------------------------------------
  pythonEnv = pkgs.python3.withPackages (ps:
    with ps; [
      fastapi        # Web-Framework für die REST-API
      uvicorn        # ASGI-Server (async, production-ready)
      psycopg2       # PostgreSQL-Client (für pgvector-Abfragen)
      requests       # HTTP-Client für Ollama + MeiliSearch APIs
      pydantic       # Request/Response-Validierung (Teil von fastapi)
    ]);

  ragScript = ./rag_api.py;

in {
  # ---------------------------------------------------------------------------
  # RAG API Service
  # ---------------------------------------------------------------------------
  systemd.services.edu-rag-api = {
    description = "Edu-Search RAG API (Klausurerstellung + semantische Suche)";

    after = [
      "network-online.target"
      "postgresql.service"
      "meilisearch.service"
      "edu-search-meili-key.service"
      "edu-indexer.service"  # Warte auf initialen Indexierungsdurchlauf
    ];
    requires = [
      "postgresql.service"
      "meilisearch.service"
    ];
    wants = [
      "network-online.target"
      "edu-search-meili-key.service"
    ];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "15s";

      # Als edu-indexer-User laufen (hat DB-Zugriff)
      User = "edu-indexer";
      Group = "users";

      ExecStart = "${pythonEnv}/bin/python ${ragScript}";

      # Warte auf PostgreSQL + MeiliSearch-Key
      ExecStartPre = let
        waitScript = pkgs.writeShellScript "edu-rag-wait" ''
          set -euo pipefail

          # Warte auf PostgreSQL
          for i in $(seq 1 30); do
            if ${pkgs.postgresql_16}/bin/pg_isready -h ${dbHost} -p ${dbPort} -U ${dbUser} -d ${dbName} > /dev/null 2>&1; then
              echo "  PostgreSQL: bereit"
              break
            fi
            if [ "$i" -eq 30 ]; then echo "  PostgreSQL: TIMEOUT" >&2; exit 1; fi
            sleep 1
          done

          # Warte auf MeiliSearch-Key
          for i in $(seq 1 30); do
            if [ -f "${meiliKeyFile}" ]; then
              echo "  MeiliSearch-Key: verfügbar"
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "  MeiliSearch-Key: nicht gefunden (Suche ohne MeiliSearch)" >&2
              # Nicht kritisch – RAG funktioniert auch ohne MeiliSearch (nur pgvector)
            fi
            sleep 1
          done

          echo "RAG API Backend-Services bereit."
        '';
      in "${waitScript}";

      Environment = [
        "RAG_OLLAMA_URL=${ollamaUrl}"
        "RAG_OLLAMA_MODEL=${ollamaModel}"
        "RAG_OLLAMA_EMBED_MODEL=${ollamaEmbedModel}"
        "RAG_DB_HOST=${dbHost}"
        "RAG_DB_PORT=${dbPort}"
        "RAG_DB_NAME=${dbName}"
        "RAG_DB_USER=${dbUser}"
        "RAG_MEILI_URL=${meiliUrl}"
        "RAG_MEILI_INDEX=${meiliIndex}"
        "RAG_MEILI_KEY_FILE=${meiliKeyFile}"
        "RAG_HOST=${ragHost}"
        "RAG_PORT=${toString ragPort}"
        "RAG_MAX_CONTEXT_DOCS=8"
        "RAG_MAX_CONTEXT_TEXT=2000"
        "PYTHONUNBUFFERED=1"
      ];

      # -----------------------------------------------------------------------
      # Sicherheits-Härtung (analog zu edu-indexer)
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

      # Kein direkter NAS-Zugriff nötig (nur DB-Abfragen)
      ReadOnlyPaths = ["/nas"];

      # Ressourcen-Limits
      LimitNOFILE = 4096;
      OOMScoreAdjust = 300;

      TimeoutStartSec = "60s";
      TimeoutStopSec = "30s";
    };
  };

  # ---------------------------------------------------------------------------
  # webui.nix: Nginx muss RAG-Endpunkt proxieren
  # ---------------------------------------------------------------------------
  # Der Nginx-Proxy wird in webui.nix konfiguriert:
  #   location /api/rag/ → http://127.0.0.1:${toString ragPort}/api/rag/
  # Hier setzen wir nur die Abhängigkeit, dass Nginx nach dem RAG-Service startet.
  systemd.services.nginx = {
    after = ["edu-rag-api.service"];
    wants = ["edu-rag-api.service"];
  };
}
