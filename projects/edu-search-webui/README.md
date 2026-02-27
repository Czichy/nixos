# Edu-Search Web-UI

Statische Single-Page-Application (SPA) für die Unterrichtsmaterial-Suche.

## Architektur

```text
Browser
  │
  ├── index.html          ← Einstiegspunkt (Suche + KI-Assistent Tabs)
  ├── style.css           ← Gesamtes Styling
  │
  ├── edu-config.js       ← API-URLs, Datei-Icons, Preview-Type-Mapping
  ├── edu-utils.js        ← HTML-Escaping, Clipboard, URL-Encoding
  ├── edu-preview.js      ← Vorschau-Modal (PDF, Bild, Audio, Video, Text, Office)
  ├── edu-cards.js        ← Ergebnis-Karten Rendering + Event-Listener
  ├── edu-search.js       ← MeiliSearch-Suche, Filter, Pagination, Init
  └── edu-rag.js          ← KI-Assistent Tab (RAG-Klausurerstellung via SSE)
```

Keine externen Abhängigkeiten – kein npm, kein CDN, kein Build-Step.

## Datenfluss

```text
Suchfeld / Filter
  → edu-search.js (debounced)
    → POST /meili/indexes/edu_documents/search
      → MeiliSearch (Auth via Nginx serverseitig injiziert)
    → edu-cards.js  (Karten rendern)
    → edu-preview.js (Vorschau öffnen bei Klick)
      → /files/…    (Nginx alias → /nas/)
      → /api/tika/  (Office → HTML Konvertierung)

KI-Assistent
  → edu-rag.js
    → POST /api/rag/klausur (SSE Streaming)
      → FastAPI → Ollama (GPU auf HOST-01)
```

## Lokale Entwicklung

```sh
# Einfacher HTTP-Server (Python)
cd src/
python3 -m http.server 8080

# Oder mit Nix
nix-shell -p python3 --run "python3 -m http.server 8080 -d src/"
```

> **Hinweis:** Die API-Endpunkte (`/meili/`, `/files/`, `/api/tika/`, `/api/rag/`)
> werden von Nginx in der MicroVM proxied. Lokal funktioniert nur das
> statische UI – für API-Zugriff muss ein Proxy oder SSH-Tunnel
> zur MicroVM eingerichtet werden.

## NixOS-Integration

Die Web-UI wird als Nix-Derivation gebaut und von Nginx ausgeliefert:

```nix
# In webui.nix:
eduWebUI = import ../../../../projects/edu-search-webui { inherit pkgs; };

# Nginx:
services.nginx.virtualHosts."edu-search".root = "${eduWebUI}";
```

Änderungen erfordern ein `nixos-rebuild` auf der MicroVM.

## Dateien

| Datei              | Zweck                                                    |
| ------------------ | -------------------------------------------------------- |
| `src/index.html`   | HTML-Struktur: Suchfeld, Filter, Ergebnisliste, KI-Tab  |
| `src/style.css`    | Design (CSS-Variablen, responsive, Print-Styles)         |
| `src/edu-config.js`| Konstanten: API-URLs, Datei-Icons, Preview-Typen         |
| `src/edu-utils.js` | Hilfsfunktionen: Escaping, Clipboard, URL-Encoding       |
| `src/edu-preview.js`| Vorschau-Modal: PDF, Bild, Audio, Video, Text, Office   |
| `src/edu-cards.js` | Ergebnis-Karten: HTML-Rendering, Event-Binding           |
| `src/edu-search.js`| Suchlogik: MeiliSearch-API, Filter, Pagination           |
| `src/edu-rag.js`   | KI-Assistent: Klausurerstellung via RAG + SSE            |
| `default.nix`      | Nix-Derivation (kopiert `src/` in den Nix-Store)         |