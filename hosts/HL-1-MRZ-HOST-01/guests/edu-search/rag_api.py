#!/usr/bin/env python3
"""
Edu-Search RAG API
==================

FastAPI-Dienst für KI-gestützte Klausurerstellung und semantische Suche.

Endpunkte:
  GET  /api/rag/health           → Healthcheck
  POST /api/rag/klausur          → Klausur/Test aus vorhandenem Material generieren (SSE Streaming)
  POST /api/rag/search-semantic  → Semantische Ähnlichkeitssuche via pgvector

Architektur (RAG = Retrieval-Augmented Generation):
  1. Nutzereingabe (Fach, Klasse, Thema, Typ)
  2. Embedding der Anfrage via Ollama (nomic-embed-text)
  3. pgvector-Suche: relevante Dokumente nach Kosinus-Ähnlichkeit
  4. MeiliSearch-Suche: Keyword-Filter (fach + klasse + typ)
  5. Union beider Ergebnisse → Kontext für LLM
  6. Ollama (mistral:7b / llama3.1:8b) → Klausur generieren
  7. Streaming-Antwort via Server-Sent Events (SSE)

Konfiguration via Umgebungsvariablen (gesetzt in rag.nix):
  RAG_OLLAMA_URL, RAG_OLLAMA_MODEL, RAG_OLLAMA_EMBED_MODEL,
  RAG_DB_HOST, RAG_DB_PORT, RAG_DB_NAME, RAG_DB_USER,
  RAG_MEILI_URL, RAG_MEILI_KEY_FILE, RAG_MEILI_INDEX,
  RAG_PORT, RAG_HOST
"""

import json
import logging
import os
import sys
import time
from typing import Iterator

import psycopg2
import psycopg2.extras
import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

# =============================================================================
# Konfiguration
# =============================================================================

OLLAMA_URL = os.getenv("RAG_OLLAMA_URL", "http://10.15.40.10:11434")
OLLAMA_MODEL = os.getenv("RAG_OLLAMA_MODEL", "mistral:7b")
OLLAMA_EMBED_MODEL = os.getenv("RAG_OLLAMA_EMBED_MODEL", "nomic-embed-text")

DB_HOST = os.getenv("RAG_DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("RAG_DB_PORT", "5432")
DB_NAME = os.getenv("RAG_DB_NAME", "edu_search")
DB_USER = os.getenv("RAG_DB_USER", "edu_indexer")

MEILI_URL = os.getenv("RAG_MEILI_URL", "http://127.0.0.1:7700")
MEILI_INDEX = os.getenv("RAG_MEILI_INDEX", "edu_documents")

RAG_HOST = os.getenv("RAG_HOST", "127.0.0.1")
RAG_PORT = int(os.getenv("RAG_PORT", "8090"))

# Maximale Anzahl Dokumente als RAG-Kontext
MAX_CONTEXT_DOCS = int(os.getenv("RAG_MAX_CONTEXT_DOCS", "8"))
# Maximale Textlänge pro Dokument im Kontext
MAX_CONTEXT_TEXT = int(os.getenv("RAG_MAX_CONTEXT_TEXT", "2000"))


def _read_meili_key() -> str:
    key_file = os.getenv("RAG_MEILI_KEY_FILE", "/run/edu-search/meili-master-key")
    if os.path.isfile(key_file):
        try:
            with open(key_file) as f:
                key = f.read().strip()
            if key:
                return key
        except OSError:
            pass
    return os.getenv("RAG_MEILI_KEY", "")


MEILI_KEY = _read_meili_key()

# =============================================================================
# Logging
# =============================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("edu-rag-api")

# =============================================================================
# FastAPI App
# =============================================================================

app = FastAPI(
    title="Edu-Search RAG API",
    description="KI-gestützte Klausurerstellung für Unterrichtsmaterialien",
    version="1.0.0",
    docs_url="/api/rag/docs",
    redoc_url=None,
    openapi_url="/api/rag/openapi.json",
)

# CORS für die Web-UI (gleiche Origin, aber zur Sicherheit erlaubt)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)

# =============================================================================
# Pydantic-Modelle
# =============================================================================


class KlausurRequest(BaseModel):
    fach: str = Field(..., description="Fach: 'Englisch' oder 'Spanisch'")
    klasse: str = Field(..., description="Klassenstufe: '5' bis '13'")
    thema: str = Field(..., description="Thema der Klausur (z.B. 'Conditional Sentences')")
    typ: str = Field(
        default="Test",
        description="Dokumenttyp: 'Test', 'Klausur', 'Übung', 'Arbeitsblatt'",
    )
    zeitaufwand_min: int = Field(
        default=45,
        ge=5,
        le=180,
        description="Zeitaufwand in Minuten",
    )
    anweisungen: str = Field(
        default="",
        max_length=500,
        description="Zusätzliche Anweisungen für die KI",
    )
    niveau: str = Field(
        default="",
        description="CEFR-Niveau: A1, A2, B1, B2, C1, C2 (optional)",
    )


class SemanticSearchRequest(BaseModel):
    query: str = Field(..., min_length=2, description="Suchanfrage")
    fach: str = Field(default="", description="Optionaler Filter: Fach")
    klasse: str = Field(default="", description="Optionaler Filter: Klasse")
    limit: int = Field(default=10, ge=1, le=50, description="Anzahl Ergebnisse")


# =============================================================================
# Hilfsfunktionen
# =============================================================================


def get_db_connection():
    """PostgreSQL-Verbindung herstellen."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        connect_timeout=10,
    )


def generate_embedding(text: str) -> list[float] | None:
    """Embedding-Vektor via Ollama nomic-embed-text generieren."""
    try:
        resp = requests.post(
            f"{OLLAMA_URL}/api/embeddings",
            json={"model": OLLAMA_EMBED_MODEL, "prompt": text[:4000]},
            timeout=30,
        )
        resp.raise_for_status()
        emb = resp.json().get("embedding")
        return emb if emb else None
    except Exception as exc:
        log.warning("Embedding-Fehler: %s", exc)
        return None


def search_by_vector(
    embedding: list[float],
    fach: str = "",
    klasse: str = "",
    limit: int = 5,
) -> list[dict]:
    """
    Semantische Ähnlichkeitssuche via pgvector.

    Nutzt cosine distance (<->) für Ranking.
    Filtert optional nach Fach und Klasse.
    """
    if not embedding:
        return []

    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
            # Embedding-Array als PostgreSQL-Vektor übergeben
            emb_str = "[" + ",".join(str(x) for x in embedding) + "]"

            conditions = ["embedding IS NOT NULL", "classification_status = 'success'"]
            where_params: list = []

            if fach:
                conditions.append("fach = %s")
                where_params.append(fach)
            if klasse:
                conditions.append("klasse = %s")
                where_params.append(klasse)

            where_clause = " AND ".join(conditions)

            cur.execute(
                f"""
                SELECT
                    filename, filepath, fach, klasse, thema, typ, niveau,
                    grammatik_themen, vokabeln_key, lernziele, hat_loesungen,
                    zeitaufwand_min, sprache,
                    LEFT(extracted_text, {MAX_CONTEXT_TEXT}) AS text_snippet,
                    1 - (embedding <=> %s::vector) AS similarity
                FROM documents
                WHERE {where_clause}
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                [emb_str] + where_params + [emb_str, limit],
            )
            rows = cur.fetchall()
            return [dict(row) for row in rows]
    except psycopg2.Error as exc:
        log.error("pgvector-Suche fehlgeschlagen: %s", exc)
        return []
    finally:
        try:
            conn.close()
        except Exception:
            pass


def search_by_keyword(
    thema: str,
    fach: str = "",
    klasse: str = "",
    typ: str = "",
    limit: int = 5,
) -> list[dict]:
    """
    Keyword-Suche via MeiliSearch API.

    Komplementär zur pgvector-Suche – findet exakte Keyword-Matches.
    """
    if not MEILI_KEY:
        return []

    filter_parts = []
    if fach:
        filter_parts.append(f'fach = "{fach}"')
    if klasse:
        filter_parts.append(f'klasse = "{klasse}"')
    if typ and typ not in ("Test", "Klausur"):
        # Typ-Filter nur wenn nicht nach Test/Klausur gesucht wird
        # (dann wollen wir QUELLEN finden, nicht Tests selbst)
        pass

    try:
        body = {
            "q": thema,
            "limit": limit,
            "attributesToRetrieve": [
                "filename", "filepath", "fach", "klasse", "thema", "typ",
                "niveau", "grammatik_themen", "vokabeln_key", "hat_loesungen",
                "zeitaufwand_min", "sprache",
            ],
        }
        if filter_parts:
            body["filter"] = " AND ".join(filter_parts)

        resp = requests.post(
            f"{MEILI_URL}/indexes/{MEILI_INDEX}/search",
            json=body,
            headers={"Authorization": f"Bearer {MEILI_KEY}"},
            timeout=10,
        )
        resp.raise_for_status()
        hits = resp.json().get("hits", [])
        # text_snippet nicht in MeiliSearch – separat aus PG laden
        return hits
    except Exception as exc:
        log.warning("MeiliSearch-Suche fehlgeschlagen: %s", exc)
        return []


def fetch_text_snippets(filepaths: list[str]) -> dict[str, str]:
    """Lädt Textauszüge für Dateipfade aus PostgreSQL (für MeiliSearch-Ergebnisse)."""
    if not filepaths:
        return {}
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute(
                f"SELECT filepath, LEFT(extracted_text, {MAX_CONTEXT_TEXT}) AS snippet "
                "FROM documents WHERE filepath = ANY(%s)",
                (filepaths,),
            )
            return {row[0]: row[1] or "" for row in cur.fetchall()}
    except Exception as exc:
        log.warning("Text-Snippet-Laden fehlgeschlagen: %s", exc)
        return {}
    finally:
        try:
            conn.close()
        except Exception:
            pass


def build_rag_context(docs: list[dict]) -> str:
    """Baut den Kontext-String für das LLM aus den gefundenen Dokumenten."""
    if not docs:
        return "(Keine relevanten Quellen gefunden)"

    parts = []
    for i, doc in enumerate(docs[:MAX_CONTEXT_DOCS], 1):
        snippet = doc.get("text_snippet") or doc.get("snippet") or ""
        thema = doc.get("thema") or ""
        grammatik = ", ".join(doc.get("grammatik_themen") or [])
        vokabeln = ", ".join(doc.get("vokabeln_key") or [])
        niveau = doc.get("niveau") or ""

        meta_parts = [f"Thema: {thema}"] if thema else []
        if niveau:
            meta_parts.append(f"Niveau: {niveau}")
        if grammatik:
            meta_parts.append(f"Grammatik: {grammatik}")
        if vokabeln:
            meta_parts.append(f"Vokabeln: {vokabeln}")

        meta = " | ".join(meta_parts)
        parts.append(
            f"--- Quelle {i}: {doc.get('filename', '?')} ({meta}) ---\n{snippet}"
        )

    return "\n\n".join(parts)


def build_klausur_prompt(req: KlausurRequest, context: str) -> str:
    """Erstellt das Klausur-Generierungs-Prompt für das LLM."""
    typ_name = req.typ
    niveau_info = f" (CEFR-Niveau {req.niveau})" if req.niveau else ""

    extra = f"\nZusätzliche Anforderungen: {req.anweisungen}" if req.anweisungen else ""

    return f"""Du bist eine erfahrene Lehrkraft für {req.fach} an einem deutschen Gymnasium.
Erstelle einen {typ_name} für Klasse {req.klasse}{niveau_info} zum Thema "{req.thema}".
Zeitrahmen: {req.zeitaufwand_min} Minuten.{extra}

VORHANDENES UNTERRICHTSMATERIAL (nutze dies als Grundlage):
{context}

ANFORDERUNGEN:
- Erstelle einen vollständigen, druckfertigen {typ_name}
- Berücksichtige das Niveau der Klasse {req.klasse}
- Basiere die Aufgaben auf dem vorhandenen Material
- Strukturiere klar: Kopfzeile (Name, Klasse, Datum), Aufgaben nummeriert, Punkteverteilung
- Variiere die Aufgabentypen (Multiple Choice, Lückentext, freie Antworten, Übersetzung)
- Gib am Ende einen LÖSUNGSSCHLÜSSEL an (mit [LÖSUNG] markiert)
- Schreibe den {typ_name} auf {req.fach} bzw. in der Zielsprache
- Antworte auf Deutsch (Aufgabenstellungen) mit {req.fach}-Inhalten

FORMAT: Markdown mit klaren Überschriften und Aufgabennummerierung."""


def stream_ollama(prompt: str) -> Iterator[str]:
    """
    Streamt die Ollama-Antwort als Server-Sent Events (SSE).

    Sendet Token für Token als SSE-Event zurück, damit die Web-UI
    die Antwort live anzeigen kann ohne auf das Ende zu warten.
    """
    try:
        resp = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": True,
                "options": {
                    "temperature": 0.7,
                    "num_predict": 3000,
                    "top_p": 0.9,
                },
            },
            stream=True,
            timeout=300,
        )
        resp.raise_for_status()

        for line in resp.iter_lines():
            if not line:
                continue
            try:
                data = json.loads(line)
                token = data.get("response", "")
                if token:
                    # SSE-Format: "data: <JSON>\n\n"
                    yield f"data: {json.dumps({'token': token})}\n\n"
                if data.get("done"):
                    yield f"data: {json.dumps({'done': True})}\n\n"
                    return
            except json.JSONDecodeError:
                continue

    except requests.exceptions.Timeout:
        yield f"data: {json.dumps({'error': 'Ollama-Timeout – GPU unter Last?'})}\n\n"
    except requests.exceptions.ConnectionError:
        yield f"data: {json.dumps({'error': f'Ollama nicht erreichbar ({OLLAMA_URL})'})}\n\n"
    except Exception as exc:
        yield f"data: {json.dumps({'error': str(exc)})}\n\n"


# =============================================================================
# API-Endpunkte
# =============================================================================


@app.get("/api/rag/health")
def health():
    """Healthcheck – prüft Erreichbarkeit aller Backend-Services."""
    status = {"status": "ok", "services": {}}

    # PostgreSQL
    try:
        conn = get_db_connection()
        conn.close()
        status["services"]["postgresql"] = "ok"
    except Exception as exc:
        status["services"]["postgresql"] = f"error: {exc}"
        status["status"] = "degraded"

    # Ollama
    try:
        resp = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        resp.raise_for_status()
        models = [m["name"] for m in resp.json().get("models", [])]
        status["services"]["ollama"] = f"ok ({len(models)} Modelle)"
    except Exception as exc:
        status["services"]["ollama"] = f"error: {exc}"
        status["status"] = "degraded"

    # MeiliSearch
    try:
        resp = requests.get(f"{MEILI_URL}/health", timeout=5)
        resp.raise_for_status()
        status["services"]["meilisearch"] = "ok"
    except Exception as exc:
        status["services"]["meilisearch"] = f"error: {exc}"
        # MeiliSearch-Ausfall ist für RAG nicht kritisch (pgvector als Fallback)

    return status


@app.post("/api/rag/klausur")
def generate_klausur(req: KlausurRequest):
    """
    Klausur/Test aus vorhandenem Unterrichtsmaterial generieren.

    Nutzt RAG (Retrieval-Augmented Generation):
    1. Embedding der Anfrage → pgvector-Suche nach ähnlichen Docs
    2. Keyword-Suche in MeiliSearch (Fach/Klasse/Thema)
    3. Union → Kontext für LLM
    4. Ollama generiert Klausur → Streaming-Response

    Returns: Server-Sent Events (SSE) Stream
    """
    log.info(
        "Klausur-Anfrage: %s Klasse %s – %s (%s, %dmin)",
        req.fach, req.klasse, req.thema, req.typ, req.zeitaufwand_min,
    )

    # 1. Query-Embedding für semantische Suche
    query_text = f"{req.fach} Klasse {req.klasse} {req.thema} {req.typ}"
    if req.niveau:
        query_text += f" {req.niveau}"

    embedding = generate_embedding(query_text)

    # 2. Parallele Suche: pgvector + MeiliSearch
    vector_docs = search_by_vector(
        embedding or [],
        fach=req.fach,
        klasse=req.klasse,
        limit=MAX_CONTEXT_DOCS // 2 + 1,
    )

    meili_hits = search_by_keyword(
        thema=req.thema,
        fach=req.fach,
        klasse=req.klasse,
        limit=MAX_CONTEXT_DOCS // 2 + 1,
    )

    # Text-Snippets für MeiliSearch-Ergebnisse aus PostgreSQL laden
    meili_paths = [h.get("filepath", "") for h in meili_hits if h.get("filepath")]
    snippets = fetch_text_snippets(meili_paths)
    for hit in meili_hits:
        fp = hit.get("filepath", "")
        hit["text_snippet"] = snippets.get(fp, "")

    # 3. Ergebnisse deduplizieren (nach filepath)
    seen_paths: set[str] = set()
    combined_docs: list[dict] = []

    for doc in vector_docs + meili_hits:
        fp = doc.get("filepath", "")
        if fp and fp not in seen_paths:
            seen_paths.add(fp)
            combined_docs.append(doc)
        if len(combined_docs) >= MAX_CONTEXT_DOCS:
            break

    if not combined_docs:
        log.warning(
            "Keine Quellen für %s Klasse %s '%s' gefunden",
            req.fach, req.klasse, req.thema,
        )

    # 4. Kontext und Prompt bauen
    context = build_rag_context(combined_docs)
    prompt = build_klausur_prompt(req, context)

    log.info(
        "Generiere Klausur mit %d Quellen (pgvector: %d, MeiliSearch: %d)",
        len(combined_docs), len(vector_docs), len(meili_hits),
    )

    # 5. Streaming-Antwort zurückgeben
    return StreamingResponse(
        stream_ollama(prompt),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # Nginx: Buffering deaktivieren für SSE
        },
    )


@app.post("/api/rag/search-semantic")
def semantic_search(req: SemanticSearchRequest):
    """
    Semantische Ähnlichkeitssuche via pgvector.

    Findet Dokumente die inhaltlich ähnlich zur Anfrage sind,
    auch wenn keine exakten Keyword-Matches vorliegen.

    Beispiel: "Conditional Sentences exercises" findet auch
    "if-clauses_worksheet.pdf" ohne direktes Keyword-Match.
    """
    embedding = generate_embedding(req.query)
    if not embedding:
        raise HTTPException(
            status_code=503,
            detail="Ollama nicht verfügbar – semantische Suche nicht möglich",
        )

    docs = search_by_vector(
        embedding,
        fach=req.fach,
        klasse=req.klasse,
        limit=req.limit,
    )

    # text_snippet aus Antwort entfernen (zu groß für API-Response)
    for doc in docs:
        doc.pop("text_snippet", None)
        # similarity als Prozent formatieren
        sim = doc.get("similarity")
        if sim is not None:
            doc["similarity_pct"] = round(float(sim) * 100, 1)

    return {
        "query": req.query,
        "hits": docs,
        "total": len(docs),
    }


# =============================================================================
# Hauptprogramm
# =============================================================================

if __name__ == "__main__":
    import uvicorn

    log.info("=" * 60)
    log.info("Edu-Search RAG API startet")
    log.info("Ollama:      %s (Modell: %s)", OLLAMA_URL, OLLAMA_MODEL)
    log.info("Embed-Model: %s", OLLAMA_EMBED_MODEL)
    log.info("PostgreSQL:  %s:%s/%s", DB_HOST, DB_PORT, DB_NAME)
    log.info("MeiliSearch: %s (Index: %s)", MEILI_URL, MEILI_INDEX)
    log.info("Lausche auf: %s:%d", RAG_HOST, RAG_PORT)
    log.info("=" * 60)

    uvicorn.run(
        app,
        host=RAG_HOST,
        port=RAG_PORT,
        log_level="info",
        access_log=True,
        proxy_headers=True,
        forwarded_allow_ips="127.0.0.1",
    )
