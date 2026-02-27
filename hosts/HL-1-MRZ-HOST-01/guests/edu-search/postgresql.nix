# PostgreSQL für Edu-Search Metadaten-Speicherung
#
# Speichert alle Dokument-Metadaten und KI-Klassifikationsergebnisse:
# - Dateipfade, Hashes, Timestamps (für Änderungserkennung)
# - Von Tika extrahierter Text + MIME-Type + Metadaten
# - Von Ollama klassifiziert: Fach, Klasse, Thema, Typ, Niveau
#
# Die Datenbank ist die "Single Source of Truth" für alle Metadaten.
# MeiliSearch kann jederzeit aus PostgreSQL-Daten rebuilt werden.
#
# BACKUP: ✅ Ja – dies ist die wichtigste Komponente für Backup,
# da die KI-Klassifikationsergebnisse hier gespeichert werden.
# Backup via pg_dump → Restic (konfiguriert in backup.nix).
{
  config,
  globals,
  lib,
  pkgs,
  ...
}: let
  dbName = "edu_search";
  dbUser = "edu_indexer";

  # pgvector Extension für semantische Ähnlichkeitssuche (Embedding-Vektoren)
  postgresPackage = pkgs.postgresql_16.withPackages (p: [p.pgvector]);

  # n8n Read-Only-Zugriff (für Workflows: Benachrichtigungen, Reports, Quizfragen)
  # n8n läuft als MicroVM auf HOST-01 im vlan40
  n8nReaderUser = "n8n_reader";
  n8nHost = globals.net.vlan40.hosts."HL-3-RZ-N8N-01".ipv4; # 10.15.40.39

  # ---------------------------------------------------------------------------
  # SQL-Schema als eigene Datei im Nix-Store
  # ---------------------------------------------------------------------------
  # Wird nur bei der initialen Erstellung der Datenbank ausgeführt.
  # Spätere Schema-Migrationen müssen manuell oder via Migrations-Tool
  # (z.B. alembic, dbmate) durchgeführt werden.
  initSchema = pkgs.writeText "edu-search-schema.sql" ''
    -- =========================================================================
    -- Edu-Search Datenbank-Schema
    -- =========================================================================
    -- Zweck: Metadaten + KI-Klassifikation von Unterrichtsmaterialien
    -- =========================================================================

    -- pgvector Extension für semantische Ähnlichkeitssuche
    CREATE EXTENSION IF NOT EXISTS vector;

    -- Haupttabelle: Ein Eintrag pro indexierter Datei
    CREATE TABLE IF NOT EXISTS documents (
        id                    SERIAL PRIMARY KEY,

        -- Datei-Identifikation
        filepath              TEXT UNIQUE NOT NULL,        -- Absoluter Pfad in der MicroVM (/nas/ina/...)
        filename              TEXT NOT NULL,               -- Nur der Dateiname (z.B. "macbeth_worksheet.docx")
        file_extension        TEXT,                        -- Kleingeschrieben (z.B. ".docx", ".pdf")
        file_size             BIGINT,                      -- Dateigröße in Bytes
        file_hash             TEXT,                        -- SHA256-Hash zur Änderungserkennung
        last_modified         TIMESTAMP WITH TIME ZONE,    -- Letzte Änderung laut Dateisystem

        -- SMB-URL für die Web-UI (Klick öffnet Datei im Explorer)
        smb_url               TEXT,                        -- z.B. smb://HL-3-RZ-SMB-01/shares/users/ina/...

        -- Von Apache Tika extrahiert
        extracted_text        TEXT,                        -- Volltext (kann sehr groß sein, bis 50k Zeichen gespeichert)
        tika_content_type     TEXT,                        -- MIME-Type laut Tika (z.B. "application/pdf")
        tika_metadata         JSONB DEFAULT '{}'::jsonb,   -- Alle Tika-Metadaten als JSON

        -- Von Ollama (LLM) klassifiziert – Basis
        fach                  TEXT,                        -- Englisch, Spanisch, Sonstige, unbekannt
        klasse                TEXT,                        -- 5-13 oder "unbekannt"
        thema                 TEXT,                        -- Kurzbeschreibung (max ~100 Zeichen)
        typ                   TEXT,                        -- Arbeitsblatt, Präsentation, Test, Klausur, Lösung, Audio, Video, Bild, Sonstiges
        niveau                TEXT,                        -- A1, A2, B1, B2, C1, C2, unbekannt
        ollama_raw            JSONB DEFAULT '{}'::jsonb,   -- Vollständige Ollama-Antwort als JSON (für Debugging)

        -- Von Ollama (LLM) klassifiziert – erweitert
        schlagwoerter         TEXT[],                      -- Array von Schlagwörtern (max 8)
        lernziele             TEXT[],                      -- Lernziele des Dokuments (1-3)
        grammatik_themen      TEXT[],                      -- Grammatikthemen (z.B. ["Present Perfect", "if-clauses"])
        vokabeln_key          TEXT[],                      -- Wichtige Vokabeln (max 10)
        hat_loesungen         BOOLEAN,                     -- Enthält das Dokument Lösungen?
        zeitaufwand_min       INTEGER,                     -- Geschätzter Zeitaufwand in Minuten
        sprache               TEXT,                        -- Dokumentsprache: "de", "en", "es"

        -- Semantischer Embedding-Vektor (nomic-embed-text, 768-dimensional)
        -- Wird für pgvector-Ähnlichkeitssuche verwendet
        embedding             vector(768),

        -- Verwaltung / Status
        indexed_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- Wann wurde diese Datei zuletzt indexiert?
        classification_status TEXT DEFAULT 'pending',      -- pending, success, failed, skipped
        error_message         TEXT,                        -- Fehlermeldung falls classification_status = 'failed'

        -- Tracking
        created_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );

    -- =========================================================================
    -- Idempotente Schema-Migration: Neue Spalten hinzufügen falls nicht vorhanden
    -- =========================================================================
    -- Diese Statements sind sicher bei bestehenden Installationen:
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS schlagwoerter    TEXT[];
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS lernziele        TEXT[];
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS grammatik_themen TEXT[];
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS vokabeln_key     TEXT[];
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS hat_loesungen    BOOLEAN;
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS zeitaufwand_min  INTEGER;
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS sprache          TEXT;
    ALTER TABLE documents ADD COLUMN IF NOT EXISTS embedding        vector(768);

    -- =========================================================================
    -- Indizes für häufige Abfragen
    -- =========================================================================

    -- Filter-Indizes (für Web-UI Dropdown-Filter)
    CREATE INDEX IF NOT EXISTS idx_doc_fach    ON documents(fach);
    CREATE INDEX IF NOT EXISTS idx_doc_klasse  ON documents(klasse);
    CREATE INDEX IF NOT EXISTS idx_doc_typ     ON documents(typ);
    CREATE INDEX IF NOT EXISTS idx_doc_niveau  ON documents(niveau);

    -- Status-Index (für den Indexer: "welche Dateien müssen noch klassifiziert werden?")
    CREATE INDEX IF NOT EXISTS idx_doc_status  ON documents(classification_status);

    -- Hash-Index (für schnelle Änderungserkennung: "hat sich die Datei geändert?")
    CREATE INDEX IF NOT EXISTS idx_doc_hash    ON documents(file_hash);

    -- Dateiname-Index (für Suche nach Dateinamen)
    CREATE INDEX IF NOT EXISTS idx_doc_filename ON documents(filename);

    -- Extension-Index (für Filterung nach Dateityp)
    CREATE INDEX IF NOT EXISTS idx_doc_ext     ON documents(file_extension);

    -- Sprach-Index (für Filterung nach Dokumentsprache)
    CREATE INDEX IF NOT EXISTS idx_doc_sprache ON documents(sprache);

    -- GIN-Index für Array-Felder (Schlagwörter, Grammatik-Themen)
    CREATE INDEX IF NOT EXISTS idx_doc_schlagwoerter   ON documents USING GIN(schlagwoerter);
    CREATE INDEX IF NOT EXISTS idx_doc_grammatik       ON documents USING GIN(grammatik_themen);

    -- IVFFlat-Index für Vektor-Ähnlichkeitssuche (pgvector)
    -- lists=100 ist ein guter Startwert für bis zu ~100k Dokumente
    CREATE INDEX IF NOT EXISTS idx_doc_embedding ON documents
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

    -- =========================================================================
    -- Trigger: updated_at automatisch aktualisieren bei UPDATEs
    -- =========================================================================
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trg_documents_updated_at ON documents;
    CREATE TRIGGER trg_documents_updated_at
        BEFORE UPDATE ON documents
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();

    -- =========================================================================
    -- View: Statistiken für Monitoring / Dashboard
    -- =========================================================================
    CREATE OR REPLACE VIEW document_stats AS
    SELECT
        COUNT(*)                                          AS total_documents,
        COUNT(*) FILTER (WHERE classification_status = 'success') AS classified,
        COUNT(*) FILTER (WHERE classification_status = 'pending') AS pending,
        COUNT(*) FILTER (WHERE classification_status = 'failed')  AS failed,
        COUNT(*) FILTER (WHERE classification_status = 'skipped') AS skipped,
        COUNT(DISTINCT fach)                              AS distinct_faecher,
        COUNT(DISTINCT klasse)                            AS distinct_klassen,
        MIN(indexed_at)                                   AS oldest_index,
        MAX(indexed_at)                                   AS newest_index
    FROM documents;

    -- =========================================================================
    -- View: Dokumente gruppiert nach Fach und Klasse (für UI-Übersicht)
    -- =========================================================================
    CREATE OR REPLACE VIEW documents_by_fach_klasse AS
    SELECT
        COALESCE(fach, 'unbekannt')     AS fach,
        COALESCE(klasse, 'unbekannt')   AS klasse,
        COUNT(*)                        AS anzahl,
        array_agg(DISTINCT typ)         AS typen
    FROM documents
    WHERE classification_status = 'success'
    GROUP BY fach, klasse
    ORDER BY fach, klasse;

    -- =========================================================================
    -- View: Kandidaten für KI-Klausurerstellung (RAG-Endpunkt)
    -- =========================================================================
    -- Enthält nur Dokumente mit ausreichend Textinhalt für die KI-Generierung.
    -- Der RAG-Service (rag_api.py) nutzt diese View um relevante Quellen zu finden.
    CREATE OR REPLACE VIEW quiz_candidates AS
    SELECT
        id,
        filepath,
        filename,
        fach,
        klasse,
        thema,
        typ,
        niveau,
        sprache,
        grammatik_themen,
        vokabeln_key,
        lernziele,
        hat_loesungen,
        zeitaufwand_min,
        -- Kurzfassung für Kontext (max 3000 Zeichen reichen für LLM)
        LEFT(extracted_text, 3000)  AS text_snippet,
        embedding
    FROM documents
    WHERE classification_status = 'success'
      AND extracted_text IS NOT NULL
      AND char_length(extracted_text) > 100;

    -- =========================================================================
    -- Berechtigungen
    -- =========================================================================
    GRANT ALL PRIVILEGES ON DATABASE edu_search TO edu_indexer;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO edu_indexer;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO edu_indexer;
    GRANT USAGE ON SCHEMA public TO edu_indexer;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO edu_indexer;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO edu_indexer;

    -- =========================================================================
    -- n8n Read-Only User (für Workflow-Automation)
    -- =========================================================================
    -- n8n (HL-3-RZ-N8N-01) greift lesend auf die documents-Tabelle zu für:
    -- - Tägliche Benachrichtigungen über neu indexierte Materialien
    -- - Wöchentliche Status-Reports
    -- - Fehler-Eskalation bei Pipeline-Problemen
    -- - KI-generierte Quizfragen aus indexiertem Material
    -- Siehe: PLAN_N8N_INTEGRATION.md, Abschnitte 2.4 + 3.3
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${n8nReaderUser}') THEN
        CREATE ROLE ${n8nReaderUser} WITH LOGIN PASSWORD 'edu_n8n_readonly';
      END IF;
    END
    $$;
    GRANT CONNECT ON DATABASE edu_search TO ${n8nReaderUser};
    GRANT USAGE ON SCHEMA public TO ${n8nReaderUser};
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${n8nReaderUser};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${n8nReaderUser};
  '';
in {
  # ---------------------------------------------------------------------------
  # PostgreSQL Service
  # ---------------------------------------------------------------------------
  services.postgresql = {
    enable = true;
    package = postgresPackage;

    settings = {
      # Lokal + für n8n-MicroVM erreichbar (vlan40)
      # n8n (10.15.40.39) greift read-only auf die documents-Tabelle zu
      listen_addresses = lib.mkForce "127.0.0.1,0.0.0.0";
      port = 5432;

      # -----------------------------------------------------------------------
      # Leichtgewichtige Einstellungen für MicroVM
      # -----------------------------------------------------------------------
      # Die edu-search DB ist klein (hauptsächlich Metadaten, kein OLAP).
      # Volltexte werden gespeichert aber selten direkt in PG abgefragt
      # (MeiliSearch übernimmt die Volltextsuche).
      shared_buffers = "128MB";
      work_mem = "8MB";
      maintenance_work_mem = "64MB";
      effective_cache_size = "256MB";

      # Wenige Verbindungen: Python-Indexer + n8n-Reader + evtl. Admin
      max_connections = 25;

      # WAL-Einstellungen für Crash-Recovery
      wal_level = "replica";
      max_wal_size = "256MB";

      # Logging
      log_min_duration_statement = 1000; # Queries > 1s loggen
      log_statement = "ddl"; # DDL-Statements loggen (CREATE, ALTER, DROP)
    };

    # -----------------------------------------------------------------------
    # Datenbank und User automatisch anlegen
    # -----------------------------------------------------------------------
    ensureDatabases = [dbName];
    ensureUsers = [
      {
        name = dbUser;
        # ensureDBOwnership erfordert eine DB mit gleichem Namen wie der User.
        # Unsere DB heißt "edu_search", der User "edu_indexer" → false setzen.
        # Berechtigungen werden stattdessen via GRANT im initialScript vergeben.
        ensureDBOwnership = false;
      }
      {
        name = n8nReaderUser;
        ensureDBOwnership = false;
      }
    ];

    # -----------------------------------------------------------------------
    # pg_hba.conf: Authentifizierung für Remote-Zugriff (n8n)
    # -----------------------------------------------------------------------
    # n8n (HL-3-RZ-N8N-01) darf sich als n8n_reader an edu_search verbinden.
    # Nur SELECT-Rechte – kann keine Daten ändern.
    authentication = lib.mkAfter ''
      # edu-indexer: lokal via TCP (kein Passwort nötig – lokaler Service in der MicroVM)
      host ${dbName} ${dbUser} 127.0.0.1/32 trust
      # n8n Workflow-Automation (read-only)
      host ${dbName} ${n8nReaderUser} ${n8nHost}/32 md5
    '';

    # -----------------------------------------------------------------------
    # Initiales Schema beim ersten Start anlegen
    # -----------------------------------------------------------------------
    # WICHTIG: initialScript wird NUR ausgeführt wenn der PostgreSQL
    # data-Ordner noch nicht existiert (erster Start nach Installation).
    # Bei bestehenden Installationen wird das Schema via edu-search-pg-migrate
    # idempotent angewendet (siehe systemd.services.edu-search-pg-migrate unten).
    initialScript = initSchema;
  };

  # ---------------------------------------------------------------------------
  # Schema-Migration: Idempotent, läuft bei jedem Start nach PostgreSQL
  # ---------------------------------------------------------------------------
  # Da initialScript nur beim allerersten DB-Init läuft, wenden wir das Schema
  # bei jedem Start erneut an. Alle SQL-Statements sind idempotent:
  #   CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS, CREATE OR REPLACE
  # Dadurch werden neue Schema-Änderungen automatisch übernommen.
  systemd.services.edu-search-pg-migrate = {
    description = "Apply Edu-Search PostgreSQL schema (idempotent)";
    after = ["postgresql.service"];
    requires = ["postgresql.service"];
    before = ["edu-indexer.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      Group = "postgres";

      ExecStart = pkgs.writeShellScript "edu-search-migrate" ''
        set -euo pipefail
        echo "Applying edu-search schema to database '${dbName}'..."
        ${pkgs.postgresql_16}/bin/psql -d ${dbName} -f ${initSchema}
        echo "Schema migration complete."
      '';
    };
  };

  # edu-indexer muss nach der Migration starten
  systemd.services.edu-indexer = {
    after = ["edu-search-pg-migrate.service"];
    requires = ["edu-search-pg-migrate.service"];
  };

  # ---------------------------------------------------------------------------
  # Impermanence: PostgreSQL-Daten + Backup-Verzeichnis persistent machen
  # ---------------------------------------------------------------------------
  # PostgreSQL-Daten müssen Reboots überleben – dies ist die wichtigste
  # persistente Komponente der gesamten Edu-Search-Architektur.
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/postgresql";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
    {
      directory = "/var/lib/edu-search-backup";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
  ];

  # ---------------------------------------------------------------------------
  # Nützliche Admin-Tools
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # pgcli: Moderner PostgreSQL-Client mit Autocomplete und Syntax-Highlighting
    pgcli
  ];

  # ---------------------------------------------------------------------------
  # Backup-Vorbereitung: pg_dump Verzeichnis
  # ---------------------------------------------------------------------------
  # Das Backup-Verzeichnis wird von backup.nix genutzt.
  # Der pg_dump-Service schreibt hierhin, Restic liest dann daraus.
  systemd.tmpfiles.settings."10-edu-pg-backup" = {
    "/var/lib/edu-search-backup".d = {
      user = "postgres";
      group = "postgres";
      mode = "0750";
    };
  };

  # pg_dump Service (wird von backup.nix referenziert)
  systemd.services.edu-search-pg-dump = {
    description = "Dump Edu-Search PostgreSQL database for backup";
    after = ["postgresql.service"];
    requires = ["postgresql.service"];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";

      ExecStart = let
        dumpScript = pkgs.writeShellScript "edu-pg-dump" ''
          set -euo pipefail
          DUMP_DIR="/var/lib/edu-search-backup"
          DUMP_FILE="$DUMP_DIR/edu_search.pgdump"
          DUMP_TMP="$DUMP_FILE.tmp"

          echo "Starting pg_dump of ${dbName}..."

          # Custom-Format (komprimiert, unterstützt parallele Restores)
          ${postgresPackage}/bin/pg_dump \
            --format=custom \
            --compress=6 \
            --file="$DUMP_TMP" \
            ${dbName}

          # Atomar ersetzen
          mv "$DUMP_TMP" "$DUMP_FILE"

          # Statistik ausgeben
          SIZE=$(stat -c%s "$DUMP_FILE" 2>/dev/null || echo "?")
          echo "pg_dump abgeschlossen: $DUMP_FILE ($SIZE bytes)"
        '';
      in "${dumpScript}";

      # Nicht den Boot blockieren
      Restart = "no";
      TimeoutStartSec = "10min";

      # Zugriff auf Dump-Verzeichnis
      ReadWritePaths = ["/var/lib/edu-search-backup"];
    };
  };

}
