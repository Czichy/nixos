#!/usr/bin/env python3
"""
Edu-Search Document Indexer
===========================

Pipeline: Datei-Watcher → Tika (Text) → Ollama (KI-Klassifikation) → PostgreSQL + MeiliSearch

Dieses Skript:
1. Überwacht NAS-Verzeichnisse auf neue/geänderte/gelöschte Dateien
2. Extrahiert Text via Apache Tika HTTP API
3. Klassifiziert via Ollama (Fach, Klasse, Thema, Typ, Niveau)
4. Speichert Metadaten in PostgreSQL
5. Indexiert in MeiliSearch für die Web-Suche

Konfiguration erfolgt über Umgebungsvariablen (gesetzt in indexer.nix):
  OLLAMA_URL, OLLAMA_MODEL, TIKA_URL, MEILI_URL, MEILI_KEY, MEILI_INDEX,
  WATCH_DIRS, SMB_BASE, DB_HOST, DB_PORT, DB_NAME, DB_USER,
  STATE_FILE, POLL_INTERVAL, FORCE_REINDEX

Aufruf:
  python indexer.py            # Normaler Daemon-Modus (Watch + Initial Indexing)
  python indexer.py --reindex  # Erzwinge Re-Indexierung aller Dateien (Oneshot)

Alle NAS-Shares werden READ-ONLY gemountet. Originaldateien werden NIEMALS verändert.
"""

import hashlib
import json
import logging
import os
import re
import signal
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import meilisearch
import psycopg2
import psycopg2.extras
import requests
from watchdog.events import FileSystemEventHandler
from watchdog.observers.polling import PollingObserver

# =============================================================================
# Konfiguration aus Umgebungsvariablen
# =============================================================================

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://10.15.40.10:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mistral:7b")
TIKA_URL = os.getenv("TIKA_URL", "http://127.0.0.1:9998")
MEILI_URL = os.getenv("MEILI_URL", "http://127.0.0.1:7700")
MEILI_INDEX = os.getenv("MEILI_INDEX", "edu_documents")


# MeiliSearch Master-Key: wird aus Datei gelesen (agenix-Secret zur Laufzeit)
# Fallback: MEILI_KEY Env-Var (für lokale Entwicklung)
def _read_meili_key() -> str:
    """Liest den MeiliSearch-Key aus der Key-Datei oder Umgebungsvariable."""
    key_file = os.getenv("MEILI_KEY_FILE", "/run/edu-search/meili-master-key")
    if os.path.isfile(key_file):
        try:
            with open(key_file, "r") as f:
                key = f.read().strip()
            if key:
                return key
        except OSError as e:
            logging.getLogger("edu-indexer").warning(
                f"Konnte MeiliSearch-Key-Datei nicht lesen: {key_file}: {e}"
            )
    # Fallback auf Umgebungsvariable (Dev-Modus)
    return os.getenv("MEILI_KEY", "")


MEILI_KEY = _read_meili_key()
WATCH_DIRS = [
    d.strip()
    for d in os.getenv("WATCH_DIRS", "/nas/ina/schule").split(",")
    if d.strip()
]
SMB_BASE = os.getenv("SMB_BASE", "smb://HL-3-RZ-SMB-01")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "edu_search")
DB_USER = os.getenv("DB_USER", "edu_indexer")
STATE_FILE = os.getenv("STATE_FILE", "/var/lib/edu-indexer/state.json")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "60"))
FORCE_REINDEX = os.getenv("FORCE_REINDEX", "0") == "1"

# Unterstützte Dateierweiterungen
SUPPORTED_EXTENSIONS = {
    # Dokumente
    ".pdf",
    ".docx",
    ".doc",
    ".pptx",
    ".ppt",
    ".odt",
    ".odp",
    ".ods",
    ".xlsx",
    ".xls",
    ".rtf",
    ".txt",
    ".html",
    ".htm",
    ".epub",
    ".csv",
    # Audio/Video (nur Metadaten-Extraktion via Tika)
    ".mp3",
    ".mp4",
    ".m4a",
    ".wav",
    ".ogg",
    ".flac",
    ".webm",
    # Bilder (nur Metadaten, kein OCR)
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".svg",
}

# Maximale Dateigröße für Textextraktion (500 MB)
MAX_FILE_SIZE = 500 * 1024 * 1024

# Maximale Textlänge die in der DB gespeichert wird
MAX_TEXT_DB = 50_000
# Maximale Textlänge die an Ollama gesendet wird
MAX_TEXT_OLLAMA = 3_000
# Maximale Textlänge die in MeiliSearch indexiert wird
MAX_TEXT_MEILI = 10_000

# HTTP-Timeouts (Sekunden)
TIKA_TIMEOUT = 180
OLLAMA_TIMEOUT = 180
MEILI_TIMEOUT = 30

# =============================================================================
# Logging
# =============================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("edu-indexer")

# Reduce noise from libraries
logging.getLogger("watchdog").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)

# =============================================================================
# Graceful Shutdown
# =============================================================================

_shutdown_requested = False


def _signal_handler(signum, _frame):
    global _shutdown_requested
    signame = signal.Signals(signum).name
    log.info("Signal %s empfangen – fahre herunter...", signame)
    _shutdown_requested = True


signal.signal(signal.SIGTERM, _signal_handler)
signal.signal(signal.SIGINT, _signal_handler)

# =============================================================================
# Hilfsfunktionen
# =============================================================================


def file_hash(filepath: str) -> str:
    """SHA256-Hash einer Datei berechnen (für Änderungserkennung)."""
    h = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError as exc:
        log.warning("Kann Hash nicht berechnen für %s: %s", filepath, exc)
        return ""


def filepath_to_smb_url(filepath: str) -> str:
    """
    Konvertiert einen lokalen NAS-Pfad in eine SMB-URL für die Web-UI.

    Mapping:
      /nas/ina/...         → smb://HL-3-RZ-SMB-01/shares/users/ina/...
      /nas/bibliothek/...  → smb://HL-3-RZ-SMB-01/shares/bibliothek/...
      /nas/dokumente/...   → smb://HL-3-RZ-SMB-01/shares/dokumente/...
    """
    path_map = {
        "/nas/ina": f"{SMB_BASE}/shares/users/ina",
        "/nas/bibliothek": f"{SMB_BASE}/shares/bibliothek",
        "/nas/dokumente": f"{SMB_BASE}/shares/dokumente",
    }
    for local_prefix, smb_prefix in sorted(path_map.items(), key=lambda x: -len(x[0])):
        if filepath.startswith(local_prefix):
            return filepath.replace(local_prefix, smb_prefix, 1)
    return filepath


def filepath_to_unc_path(filepath: str) -> str:
    """
    Konvertiert einen lokalen NAS-Pfad in einen Windows UNC-Pfad.
    Nützlich als Alternative zu smb:// für Windows-Kompatibilität.

    Mapping:
      /nas/ina/...         → \\\\HL-3-RZ-SMB-01\\shares\\users\\ina\\...
    """
    smb = filepath_to_smb_url(filepath)
    if smb.startswith("smb://"):
        unc = smb.replace("smb://", "\\\\").replace("/", "\\")
        return unc
    return filepath


# =============================================================================
# Apache Tika – Textextraktion
# =============================================================================


def extract_text_tika(filepath: str) -> tuple[str, str, dict]:
    """
    Text via Apache Tika HTTP API extrahieren.

    Args:
        filepath: Absoluter Pfad zur Datei

    Returns:
        Tuple von (extrahierter_text, content_type, tika_metadata_dict)
        Bei Fehler: ("", "error", {})
    """
    text = ""
    content_type = "unknown"
    metadata = {}

    try:
        # 1. Textextraktion via PUT /tika
        with open(filepath, "rb") as f:
            resp = requests.put(
                f"{TIKA_URL}/tika",
                data=f,
                headers={"Accept": "text/plain"},
                timeout=TIKA_TIMEOUT,
            )
            resp.raise_for_status()
            text = resp.text.strip()

        # 2. Metadaten separat holen via PUT /meta
        with open(filepath, "rb") as f:
            meta_resp = requests.put(
                f"{TIKA_URL}/meta",
                data=f,
                headers={"Accept": "application/json"},
                timeout=TIKA_TIMEOUT,
            )
            meta_resp.raise_for_status()
            metadata = meta_resp.json()
            content_type = metadata.get("Content-Type", "unknown")
            # Content-Type kann ein Array sein – ersten Eintrag nehmen
            if isinstance(content_type, list):
                content_type = content_type[0] if content_type else "unknown"

    except requests.exceptions.Timeout:
        log.warning("Tika-Timeout für %s (Datei zu groß?)", filepath)
        return "", "timeout", {}
    except requests.exceptions.ConnectionError:
        log.error("Tika nicht erreichbar (%s) – läuft der Service?", TIKA_URL)
        return "", "error", {}
    except requests.exceptions.HTTPError as exc:
        log.warning("Tika HTTP-Fehler für %s: %s", filepath, exc)
        return "", "error", {}
    except Exception as exc:
        log.error("Tika-Extraktion fehlgeschlagen für %s: %s", filepath, exc)
        return "", "error", {}

    return text, content_type, metadata


# =============================================================================
# Ollama – KI-Klassifikation
# =============================================================================

CLASSIFICATION_PROMPT = """Du bist ein Klassifikations-Assistent für Unterrichtsmaterialien einer Lehrerin für Englisch und Spanisch an einem deutschen Gymnasium.

Analysiere den folgenden Dateinamen und Textinhalt und extrahiere die Metadaten.

REGELN:
- Antworte NUR mit validem JSON, KEINE Erklärungen davor oder danach
- Wenn du unsicher bist, verwende "unbekannt"
- Das Thema soll kurz und prägnant sein (max 50 Zeichen)
- Beachte den Dateinamen als wichtigen Hinweis

PFLICHTFELDER im JSON:
{{
  "fach": "Englisch" oder "Spanisch" oder "Sonstige",
  "klasse": "5" bis "13" oder "unbekannt",
  "thema": "kurze Beschreibung (max 50 Zeichen)",
  "typ": "Arbeitsblatt" oder "Präsentation" oder "Test" oder "Klausur" oder "Übung" oder "Vokabeln" oder "Grammatik" oder "Lektüre" oder "Audio" oder "Video" oder "Bild" oder "Sonstiges",
  "niveau": "A1" oder "A2" oder "B1" oder "B2" oder "C1" oder "C2" oder "unbekannt"
}}

DATEINAME: {filename}

TEXT (erste 3000 Zeichen):
{text_snippet}"""


def classify_with_ollama(text: str, filename: str) -> dict:
    """
    Text via Ollama LLM klassifizieren.

    Args:
        text: Extrahierter Klartext (wird auf MAX_TEXT_OLLAMA gekürzt)
        filename: Dateiname (wichtiger Kontext-Hinweis für das LLM)

    Returns:
        Dict mit Schlüsseln: fach, klasse, thema, typ, niveau, _raw
    """
    snippet = text[:MAX_TEXT_OLLAMA] if text else "(kein Text extrahiert)"

    prompt = CLASSIFICATION_PROMPT.format(
        filename=filename,
        text_snippet=snippet,
    )

    default_result = {
        "fach": "unbekannt",
        "klasse": "unbekannt",
        "thema": "",
        "typ": "Sonstiges",
        "niveau": "unbekannt",
        "_raw": "",
    }

    try:
        resp = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False,
                "format": "json",
                "options": {
                    "temperature": 0.1,
                    "num_predict": 300,
                    "top_p": 0.9,
                },
            },
            timeout=OLLAMA_TIMEOUT,
        )
        resp.raise_for_status()
        raw_response = resp.json().get("response", "")

        # JSON aus der Antwort extrahieren
        # Ollama mit format=json sollte reines JSON liefern,
        # aber manchmal gibt es Wrapper-Text
        json_match = re.search(r"\{[^{}]*\}", raw_response, re.DOTALL)
        if json_match:
            parsed = json.loads(json_match.group())
            result = {
                "fach": str(parsed.get("fach", "unbekannt"))[:50],
                "klasse": str(parsed.get("klasse", "unbekannt"))[:10],
                "thema": str(parsed.get("thema", ""))[:100],
                "typ": str(parsed.get("typ", "Sonstiges"))[:50],
                "niveau": str(parsed.get("niveau", "unbekannt"))[:10],
                "_raw": raw_response[:2000],
            }
            return result

        log.warning("Ollama-Antwort enthielt kein JSON: %.200s", raw_response)
        default_result["_raw"] = raw_response[:2000]
        return default_result

    except requests.exceptions.Timeout:
        log.warning("Ollama-Timeout für %s – GPU unter Last?", filename)
        default_result["_raw"] = "TIMEOUT"
        return default_result
    except requests.exceptions.ConnectionError:
        log.warning("Ollama nicht erreichbar (%s) – HOST-01 offline?", OLLAMA_URL)
        default_result["_raw"] = "CONNECTION_ERROR"
        return default_result
    except json.JSONDecodeError as exc:
        log.warning("Ollama-Antwort kein valides JSON: %s", exc)
        default_result["_raw"] = f"JSON_ERROR: {exc}"
        return default_result
    except Exception as exc:
        log.error("Ollama-Klassifikation fehlgeschlagen: %s", exc)
        default_result["_raw"] = f"ERROR: {exc}"
        return default_result


# =============================================================================
# Datenbank-Verbindung
# =============================================================================


def get_db_connection():
    """PostgreSQL-Verbindung herstellen."""
    return psycopg2.connect(host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER)


# =============================================================================
# MeiliSearch-Client
# =============================================================================


def get_meili_client():
    """MeiliSearch-Client erstellen und Index konfigurieren (idempotent)."""
    client = meilisearch.Client(MEILI_URL, MEILI_KEY or None)
    index = client.index(MEILI_INDEX)

    # Index-Einstellungen setzen (idempotent – kann bei jedem Start aufgerufen werden)
    log.info("Konfiguriere MeiliSearch-Index '%s'...", MEILI_INDEX)

    try:
        # Index erstellen falls nicht vorhanden
        client.create_index(MEILI_INDEX, {"primaryKey": "id"})
    except meilisearch.errors.MeilisearchApiError:
        pass  # Index existiert bereits – OK

    # Filterbare Attribute (für Dropdown-Filter in der Web-UI)
    index.update_filterable_attributes(
        [
            "fach",
            "klasse",
            "typ",
            "niveau",
            "file_extension",
        ]
    )

    # Sortierbare Attribute
    index.update_sortable_attributes(
        [
            "klasse",
            "filename",
            "last_modified",
        ]
    )

    # Durchsuchbare Attribute (Reihenfolge = Priorität)
    index.update_searchable_attributes(
        [
            "thema",  # Höchste Priorität
            "filename",  # Dateiname
            "fach",  # Fach als Suchbegriff
            "content",  # Volltext (niedrigste Priorität)
        ]
    )

    # Angezeigte Attribute (KEIN content – hält Antworten klein)
    index.update_displayed_attributes(
        [
            "id",
            "filename",
            "filepath",
            "fach",
            "klasse",
            "thema",
            "typ",
            "niveau",
            "smb_url",
            "unc_path",
            "last_modified",
            "file_extension",
        ]
    )

    log.info("MeiliSearch-Index '%s' konfiguriert.", MEILI_INDEX)
    return index


# =============================================================================
# Kernlogik: Einzelne Datei verarbeiten
# =============================================================================


def process_file(filepath: str, db_conn, meili_index) -> bool:
    """
    Eine einzelne Datei durch die komplette Pipeline schicken.

    Returns:
        True wenn die Datei verarbeitet wurde, False wenn übersprungen.
    """
    path = Path(filepath)

    # Nur unterstützte Dateien
    if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        return False

    # Dateigröße prüfen
    try:
        stat = path.stat()
    except OSError as exc:
        log.warning("Datei nicht lesbar: %s: %s", filepath, exc)
        return False

    if stat.st_size > MAX_FILE_SIZE:
        log.warning(
            "Datei zu groß (%d MB), überspringe: %s",
            stat.st_size // (1024 * 1024),
            filepath,
        )
        return False

    if stat.st_size == 0:
        log.debug("Leere Datei, überspringe: %s", filepath)
        return False

    # Hash berechnen
    current_hash = file_hash(filepath)
    if not current_hash:
        return False

    # Prüfe ob bereits indexiert und unverändert (sofern kein Force-Reindex)
    if not FORCE_REINDEX:
        try:
            with db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
                cur.execute(
                    "SELECT file_hash, classification_status FROM documents WHERE filepath = %s",
                    (filepath,),
                )
                row = cur.fetchone()
                if (
                    row
                    and row["file_hash"] == current_hash
                    and row["classification_status"] == "success"
                ):
                    log.debug("Unverändert, überspringe: %s", filepath)
                    return False
        except psycopg2.Error as exc:
            log.warning("DB-Abfrage fehlgeschlagen für %s: %s", filepath, exc)
            db_conn.rollback()

    log.info("Verarbeite: %s", filepath)

    # 1. Text extrahieren via Tika
    text, content_type, tika_meta = extract_text_tika(filepath)

    # 2. KI-Klassifikation via Ollama
    classification = {
        "fach": "unbekannt",
        "klasse": "unbekannt",
        "thema": "",
        "typ": "Sonstiges",
        "niveau": "unbekannt",
        "_raw": "",
    }
    status = "pending"
    error_msg = None

    audio_video_exts = {".mp3", ".mp4", ".m4a", ".wav", ".ogg", ".flac", ".webm"}
    image_exts = {".jpg", ".jpeg", ".png", ".gif", ".svg"}

    if text and len(text.strip()) > 20:
        try:
            classification = classify_with_ollama(text, path.name)
            if classification.get("_raw", "").startswith(
                ("TIMEOUT", "CONNECTION_ERROR", "ERROR")
            ):
                status = "pending"  # Ollama nicht verfügbar – später erneut versuchen
                error_msg = classification.get("_raw", "")
            else:
                status = "success"
        except Exception as exc:
            status = "failed"
            error_msg = str(exc)[:500]
            log.error("Klassifikation fehlgeschlagen für %s: %s", filepath, exc)
    elif path.suffix.lower() in audio_video_exts:
        status = "skipped"
        classification["typ"] = (
            "Audio"
            if path.suffix.lower() in {".mp3", ".m4a", ".wav", ".ogg", ".flac"}
            else "Video"
        )
        # Versuche Fach/Klasse aus Dateiname und Pfad zu erraten
        classification = classify_with_ollama(
            f"Dateiname: {path.name}\nPfad: {filepath}\n(Audio/Video-Datei, kein Textinhalt)",
            path.name,
        )
        status = (
            "success"
            if not classification.get("_raw", "").startswith(
                ("TIMEOUT", "CONNECTION_ERROR")
            )
            else "skipped"
        )
    elif path.suffix.lower() in image_exts:
        status = "skipped"
        classification["typ"] = "Bild"
    else:
        status = "failed" if content_type == "error" else "skipped"
        error_msg = (
            "Kein Text extrahiert"
            if status == "skipped"
            else f"Tika-Fehler: {content_type}"
        )

    # 3. SMB-URL und UNC-Pfad generieren
    smb_url = filepath_to_smb_url(filepath)
    unc_path = filepath_to_unc_path(filepath)

    # 4. In PostgreSQL speichern (UPSERT)
    try:
        with db_conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO documents (
                    filepath, filename, file_extension, file_size, file_hash,
                    last_modified, smb_url, extracted_text, tika_content_type,
                    tika_metadata, fach, klasse, thema, typ, niveau,
                    ollama_raw, indexed_at, classification_status, error_message
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                ON CONFLICT (filepath) DO UPDATE SET
                    filename = EXCLUDED.filename,
                    file_extension = EXCLUDED.file_extension,
                    file_size = EXCLUDED.file_size,
                    file_hash = EXCLUDED.file_hash,
                    last_modified = EXCLUDED.last_modified,
                    smb_url = EXCLUDED.smb_url,
                    extracted_text = EXCLUDED.extracted_text,
                    tika_content_type = EXCLUDED.tika_content_type,
                    tika_metadata = EXCLUDED.tika_metadata,
                    fach = EXCLUDED.fach,
                    klasse = EXCLUDED.klasse,
                    thema = EXCLUDED.thema,
                    typ = EXCLUDED.typ,
                    niveau = EXCLUDED.niveau,
                    ollama_raw = EXCLUDED.ollama_raw,
                    indexed_at = EXCLUDED.indexed_at,
                    classification_status = EXCLUDED.classification_status,
                    error_message = EXCLUDED.error_message
                """,
                (
                    filepath,
                    path.name,
                    path.suffix.lower(),
                    stat.st_size,
                    current_hash,
                    datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc),
                    smb_url,
                    text[:MAX_TEXT_DB] if text else None,
                    content_type,
                    json.dumps(tika_meta, default=str),
                    classification.get("fach"),
                    classification.get("klasse"),
                    classification.get("thema"),
                    classification.get("typ"),
                    classification.get("niveau"),
                    json.dumps(classification.get("_raw", ""), default=str),
                    datetime.now(timezone.utc),
                    status,
                    error_msg,
                ),
            )
        db_conn.commit()
    except psycopg2.Error as exc:
        log.error("PostgreSQL-Fehler für %s: %s", filepath, exc)
        db_conn.rollback()
        return False

    # 5. In MeiliSearch indexieren
    doc_id = current_hash[:16]
    meili_doc = {
        "id": doc_id,
        "filename": path.name,
        "filepath": filepath,
        "file_extension": path.suffix.lower(),
        "smb_url": smb_url,
        "unc_path": unc_path,
        "content": text[:MAX_TEXT_MEILI] if text else "",
        "fach": classification.get("fach", "unbekannt"),
        "klasse": classification.get("klasse", "unbekannt"),
        "thema": classification.get("thema", ""),
        "typ": classification.get("typ", "Sonstiges"),
        "niveau": classification.get("niveau", "unbekannt"),
        "last_modified": int(stat.st_mtime),
    }

    try:
        meili_index.add_documents([meili_doc])
    except Exception as exc:
        log.error("MeiliSearch-Fehler für %s: %s", filepath, exc)
        # Nicht kritisch – Datei ist in PostgreSQL gespeichert

    log.info(
        "Indexiert: %s → %s/%s/%s [%s]",
        path.name,
        classification.get("fach", "?"),
        classification.get("klasse", "?"),
        classification.get("thema", "?"),
        status,
    )
    return True


def delete_from_index(filepath: str, db_conn, meili_index):
    """Eine gelöschte Datei aus PostgreSQL und MeiliSearch entfernen."""
    try:
        with db_conn.cursor() as cur:
            cur.execute(
                "SELECT file_hash FROM documents WHERE filepath = %s", (filepath,)
            )
            row = cur.fetchone()
            if row:
                doc_id = row[0][:16]
                try:
                    meili_index.delete_document(doc_id)
                except Exception:
                    pass
            cur.execute("DELETE FROM documents WHERE filepath = %s", (filepath,))
        db_conn.commit()
        log.info("Gelöscht aus Index: %s", filepath)
    except psycopg2.Error as exc:
        log.error("DB-Fehler beim Löschen von %s: %s", filepath, exc)
        db_conn.rollback()


# =============================================================================
# Dateisystem-Watcher (Watchdog)
# =============================================================================


class EduFileHandler(FileSystemEventHandler):
    """Reagiert auf Dateisystem-Ereignisse und löst die Indexierung aus."""

    def __init__(self, db_conn, meili_index):
        self.db_conn = db_conn
        self.meili_index = meili_index

    def on_created(self, event):
        if not event.is_directory and not _shutdown_requested:
            try:
                process_file(event.src_path, self.db_conn, self.meili_index)
            except Exception as exc:
                log.error("Fehler on_created %s: %s", event.src_path, exc)

    def on_modified(self, event):
        if not event.is_directory and not _shutdown_requested:
            try:
                process_file(event.src_path, self.db_conn, self.meili_index)
            except Exception as exc:
                log.error("Fehler on_modified %s: %s", event.src_path, exc)

    def on_deleted(self, event):
        if not event.is_directory and not _shutdown_requested:
            try:
                delete_from_index(event.src_path, self.db_conn, self.meili_index)
            except Exception as exc:
                log.error("Fehler on_deleted %s: %s", event.src_path, exc)

    def on_moved(self, event):
        if not event.is_directory and not _shutdown_requested:
            try:
                delete_from_index(event.src_path, self.db_conn, self.meili_index)
                process_file(event.dest_path, self.db_conn, self.meili_index)
            except Exception as exc:
                log.error(
                    "Fehler on_moved %s → %s: %s", event.src_path, event.dest_path, exc
                )


# =============================================================================
# Initiale Indizierung
# =============================================================================


def initial_indexing(db_conn, meili_index):
    """Alle Dateien in den Watch-Verzeichnissen einmalig durchgehen."""
    log.info(
        "Starte %s...",
        "Re-Indexierung (FORCE)" if FORCE_REINDEX else "initiale Indexierung",
    )
    count = 0
    errors = 0
    skipped = 0

    for watch_dir in WATCH_DIRS:
        watch_path = Path(watch_dir)
        if not watch_path.exists():
            log.warning("Verzeichnis existiert nicht: %s", watch_dir)
            continue
        if not watch_path.is_dir():
            log.warning("Kein Verzeichnis: %s", watch_dir)
            continue

        log.info("Scanne: %s", watch_dir)
        for fpath in sorted(watch_path.rglob("*")):
            if _shutdown_requested:
                log.info("Shutdown angefordert – breche initiale Indexierung ab.")
                break

            if not fpath.is_file():
                continue
            if fpath.suffix.lower() not in SUPPORTED_EXTENSIONS:
                continue

            try:
                was_processed = process_file(str(fpath), db_conn, meili_index)
                if was_processed:
                    count += 1
                else:
                    skipped += 1
            except Exception as exc:
                log.error("Fehler bei %s: %s", fpath, exc)
                errors += 1

    log.info(
        "Indexierung abgeschlossen: %d verarbeitet, %d übersprungen, %d Fehler.",
        count,
        skipped,
        errors,
    )
    return count


# =============================================================================
# Hauptprogramm
# =============================================================================


def main():
    """Haupteinstiegspunkt für den Edu-Search Indexer."""
    reindex_mode = "--reindex" in sys.argv or FORCE_REINDEX

    log.info("=" * 60)
    log.info("Edu-Search Indexer gestartet")
    log.info("=" * 60)
    log.info(
        "Modus:       %s",
        "Re-Indexierung (FORCE)" if reindex_mode else "Daemon (Watch + Initial)",
    )
    log.info("Watch-Dirs:  %s", WATCH_DIRS)
    log.info("Ollama:      %s (Modell: %s)", OLLAMA_URL, OLLAMA_MODEL)
    log.info("Tika:        %s", TIKA_URL)
    log.info("MeiliSearch: %s (Index: %s)", MEILI_URL, MEILI_INDEX)
    log.info("PostgreSQL:  %s:%s/%s (User: %s)", DB_HOST, DB_PORT, DB_NAME, DB_USER)
    log.info("Polling:     alle %ds", POLL_INTERVAL)
    log.info("=" * 60)

    # Verbindungen aufbauen
    log.info("Verbinde mit PostgreSQL...")
    try:
        db_conn = get_db_connection()
        db_conn.autocommit = False
        log.info("PostgreSQL-Verbindung hergestellt.")
    except psycopg2.Error as exc:
        log.critical("PostgreSQL-Verbindung fehlgeschlagen: %s", exc)
        sys.exit(1)

    log.info("Verbinde mit MeiliSearch...")
    try:
        meili_index = get_meili_client()
        log.info("MeiliSearch-Client bereit.")
    except Exception as exc:
        log.critical("MeiliSearch-Verbindung fehlgeschlagen: %s", exc)
        sys.exit(1)

    # Initiale Indexierung / Re-Indexierung
    processed = initial_indexing(db_conn, meili_index)

    # Im Reindex-Modus: nach der Indexierung beenden
    if reindex_mode:
        log.info("Re-Indexierung abgeschlossen (%d Dateien). Beende.", processed)
        db_conn.close()
        return

    # Im Daemon-Modus: Dateisystem-Watcher starten
    if _shutdown_requested:
        log.info("Shutdown vor Watcher-Start angefordert. Beende.")
        db_conn.close()
        return

    log.info(
        "Starte Dateisystem-Watcher (PollingObserver, Interval: %ds)...", POLL_INTERVAL
    )
    handler = EduFileHandler(db_conn, meili_index)
    observer = PollingObserver(timeout=POLL_INTERVAL)

    active_dirs = 0
    for watch_dir in WATCH_DIRS:
        d = watch_dir.strip()
        if os.path.isdir(d):
            observer.schedule(handler, d, recursive=True)
            log.info("Überwache: %s", d)
            active_dirs += 1
        else:
            log.warning("Verzeichnis existiert nicht, überspringe Watch: %s", d)

    if active_dirs == 0:
        log.error("Keine gültigen Watch-Verzeichnisse gefunden! Beende.")
        db_conn.close()
        sys.exit(1)

    observer.start()
    log.info(
        "Dateisystem-Watcher aktiv (%d Verzeichnisse, Polling alle %ds).",
        active_dirs,
        POLL_INTERVAL,
    )

    # Hauptschleife: Warte auf Shutdown-Signal
    try:
        while not _shutdown_requested:
            time.sleep(1)

            # Regelmäßig prüfen ob die DB-Verbindung noch lebt
            # (PostgreSQL schließt idle Connections nach einem Timeout)
            try:
                db_conn.isolation_level  # noqa: B018 – triggers check
            except psycopg2.InterfaceError:
                log.warning("DB-Verbindung verloren – stelle wieder her...")
                try:
                    db_conn = get_db_connection()
                    db_conn.autocommit = False
                    handler.db_conn = db_conn
                    log.info("DB-Verbindung wiederhergestellt.")
                except psycopg2.Error as exc:
                    log.error("DB-Reconnect fehlgeschlagen: %s", exc)
                    # Warte und versuche es beim nächsten Loop
                    time.sleep(10)

    except KeyboardInterrupt:
        log.info("KeyboardInterrupt – fahre herunter...")

    # Graceful Shutdown
    log.info("Stoppe Dateisystem-Watcher...")
    observer.stop()
    observer.join(timeout=10)

    log.info("Schließe Datenbankverbindung...")
    try:
        db_conn.close()
    except Exception:
        pass

    log.info("=" * 60)
    log.info("Edu-Search Indexer beendet.")
    log.info("=" * 60)


if __name__ == "__main__":
    main()
