# 🔄 n8n-Integrationsanalyse – Edu-Search, Ollama & bestehende MicroVMs

## Workflow-Automation-Bewertung für die gesamte Infrastruktur

> **Ziel:** Bewertung, ob und wie n8n (HL-3-RZ-N8N-01) sinnvoll mit Edu-Search, Ollama und den
> bestehenden aktiven MicroVMs integriert werden kann. Für jede Integration werden konkrete
> Anwendungsbeispiele aufgezeigt.

> **Stand:** Analyse basierend auf aktuellem Repo-Stand. n8n läuft bereits als MicroVM auf
> HOST-01 mit Anthropic Claude API-Key und Restic-Backup.

---

## Inhaltsverzeichnis

1. [Infrastruktur-Übersicht](#1-infrastruktur-übersicht)
2. [n8n ↔ Ollama: KI-Orchestrierung (Höchste Synergie)](#2-n8n--ollama-ki-orchestrierung-höchste-synergie)
3. [n8n ↔ Edu-Search: Detailanalyse](#3-n8n--edu-search-detailanalyse)
4. [n8n ↔ Aktive MicroVMs: Integrationsbewertung](#4-n8n--aktive-microvms-integrationsbewertung)
5. [Priorisierte Umsetzungsreihenfolge](#5-priorisierte-umsetzungsreihenfolge)
6. [Technische Voraussetzungen](#6-technische-voraussetzungen)
7. [Offene Fragen & Risiken](#7-offene-fragen--risiken)
8. [Fazit](#8-fazit)

---

## 1. Infrastruktur-Übersicht

### Aktive MicroVMs nach Host

| Host | MicroVM | Hostname | Funktion | Kategorie |
|---|---|---|---|---|
| **HOST-01** | samba | HL-3-RZ-SMB-01 | NAS/Dateifreigaben | Storage |
| | ente | HL-3-RZ-ENTE-01 | Foto-Speicher (Google-Photos-Alternative) | Media |
| | syncthing | HL-3-RZ-SYNC-01 | Dateisynchronisation (Christian) | Storage |
| | sync_ina | HL-3-RZ-SYNC-02 | Dateisynchronisation (Ina) | Storage |
| | influxdb | HL-3-RZ-INFLUX-01 | Zeitseriendatenbank | Monitoring |
| | forgejo | HL-3-RZ-GIT-01 | Git-Hosting | Development |
| | ibkr-flex | HL-3-RZ-IBKR-01 | IBKR Flex Report Downloader | Finance |
| | ib-gateway | HL-3-RZ-IBGW-01 | Interactive Brokers API Gateway | Finance |
| | parseable | HL-3-RZ-LOG-01 | Log-Management | Monitoring |
| | s3 | HL-3-RZ-S3-01 | S3-kompatibler Objektspeicher (Garage) | Storage |
| | grafana | HL-3-RZ-GRAFANA-01 | Dashboards & Alerting | Monitoring |
| | victoria | HL-3-RZ-METRICS-01 | VictoriaMetrics (Metriken) | Monitoring |
| | **n8n** | **HL-3-RZ-N8N-01** | **Workflow Automation** | **Automation** |
| | **edu-search** | **HL-3-RZ-EDU-01** | **Unterrichtsmaterial-Suche** | **Documents** |
| | paperless | HL-3-RZ-PAPERLESS-01 | Dokumentenmanagement (OCR, Tagging) | Documents |
| **HOST-02** | adguardhome | HL-3-RZ-DNS-01 | DNS Ad-Blocker | Infrastructure |
| | caddy | HL-3-DMZ-PROXY-01 | Reverse Proxy (DMZ) | Infrastructure |
| | kanidm | HL-3-RZ-AUTH-01 | Identity Provider (SSO/OAuth2) | Infrastructure |
| | nginx | – | Webserver / Reverse Proxy | Infrastructure |
| | vaultwarden | HL-3-RZ-VAULT-01 | Passwort-Manager | Security |
| **HOST-03** | hass | HL-3-RZ-HASS-01 | Home Assistant (Smart Home) | Home Automation |
| | homepage | HL-3-RZ-HOME-01 | Dashboard | Infrastructure |
| | mosquitto | HL-3-RZ-MQTT-01 | MQTT Broker | Home Automation |
| | node-red | HL-3-RZ-RED-01 | Visual Flow Programming (IoT) | Home Automation |
| | powermeter | HL-3-RZ-POWER-02 | Stromzähler-Auswertung | Home Automation |
| | unifi | HL-3-RZ-UNIFI-01 | UniFi Network Controller | Infrastructure |

### n8n – Aktueller Stand

n8n läuft als MicroVM auf HOST-01 (vlan40, IP: 10.15.40.39) mit folgenden Ressourcen:

- **Domain:** `n8n.czichy.com`
- **Port:** 5678
- **Secrets:**
  - `n8n-encryption-key` (interne Verschlüsselung)
  - `n8n-anthropic-api-key` (Claude AI – bereits konfiguriert!)
- **Backup:** Restic → OneDrive NAS (täglich 03:00)
- **Reverse Proxy:** Caddy (HOST-02 intern + PAZ-PROXY-01 extern)
- **Webhook-URL:** `https://n8n.czichy.com/`
- **Persistenz:** `/var/lib/n8n` (via impermanence nach `/persist`)

### KI-Backends – Aktueller Stand

| Backend | Status | Wo | Zugang von n8n | Kosten | Qualität |
|---|---|---|---|---|---|
| **Ollama** (ai.nix MicroVM) | ⚠️ CPU-only, 16GB RAM, 20 vCPUs | MicroVM auf HOST-01 | ✅ vlan40 | Gratis, lokal | ⚠️ Langsam ohne GPU |
| **Ollama** (geplant: nativ HOST-01) | 🔜 PLAN_EDU_SEARCH Phase 1 | Nativ auf HOST-01 (CUDA, GTX 1660 SUPER 6GB) | ✅ `http://10.15.40.10:11434` | Gratis, lokal | ✅ Schnell mit GPU |
| **Anthropic Claude** | ✅ Aktiv | Cloud API | ✅ API-Key in n8n konfiguriert | Bezahlt (per Token) | ✅ Sehr hoch |

> **Kernaussage:** Sobald Ollama nativ auf HOST-01 mit GPU läuft (PLAN_EDU_SEARCH Phase 1),
> wird n8n zum **zentralen KI-Orchestrator** mit zwei komplementären Backends:
> - **Ollama** (lokal, gratis, GPU-beschleunigt, privat) → Bulk-Aufgaben, on-premise Daten
> - **Claude** (Cloud, bezahlt, höchste Qualität) → Komplexe Analysen, Fallback

---

## 2. n8n ↔ Ollama: KI-Orchestrierung (Höchste Synergie)

### ⭐⭐⭐⭐⭐ – Stärkster Integrationspunkt der gesamten Infrastruktur

### 2.1 Warum Ollama + n8n ein Game-Changer ist

n8n hat **native Nodes** für beide KI-Backends:

| n8n-Node | Backend | Funktion |
|---|---|---|
| **Ollama Chat Model** | Ollama (lokal) | Chat-Completion, Text-Generierung |
| **Ollama Embeddings** | Ollama (lokal) | Text-Embeddings für Vektor-Suche |
| **Anthropic Claude** | Claude (Cloud) | Chat-Completion, komplexe Analyse |
| **AI Agent** | Beide | LangChain-Agent mit Tools, kann zwischen Modellen wählen |
| **Text Classifier** | Beide | Automatische Textklassifikation |
| **Summarizer** | Beide | Textzusammenfassung |
| **Sentiment Analysis** | Beide | Stimmungsanalyse |

### 2.2 KI-Strategie: "Ollama first, Claude fallback"

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    n8n KI-Entscheidungslogik                        │
│                                                                     │
│  Aufgabe eingehend                                                  │
│       │                                                             │
│       ▼                                                             │
│  ┌─────────────┐    JA     ┌──────────────────────────────────┐    │
│  │ Private      ├─────────►│ Ollama (lokal, GPU, gratis)      │    │
│  │ Daten?       │          │ mistral:7b / llama3.1:8b         │    │
│  └──────┬──────┘          │ → Rechnungen, Dokumente, Logs    │    │
│         │ NEIN             └──────────────────────────────────┘    │
│         ▼                                                          │
│  ┌─────────────┐    JA     ┌──────────────────────────────────┐    │
│  │ Bulk/        ├─────────►│ Ollama (lokal, GPU, gratis)      │    │
│  │ Repetitiv?   │          │ → Klassifikation, Tagging,       │    │
│  └──────┬──────┘          │   tägliche Reports               │    │
│         │ NEIN             └──────────────────────────────────┘    │
│         ▼                                                          │
│  ┌─────────────┐    JA     ┌──────────────────────────────────┐    │
│  │ Komplex /    ├─────────►│ Anthropic Claude (Cloud, bezahlt)│    │
│  │ Hohe         │          │ → Portfolio-Analyse, komplexe    │    │
│  │ Qualität?    │          │   Zusammenfassungen, Debugging   │    │
│  └──────┬──────┘          └──────────────────────────────────┘    │
│         │ NEIN                                                     │
│         ▼                                                          │
│  ┌──────────────────────────────────────────────────────────┐      │
│  │ Ollama (Default – spart Kosten, schnell, lokal)          │      │
│  └──────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Voraussetzungen

Ollama muss nativ auf HOST-01 laufen (PLAN_EDU_SEARCH Phase 1):

```nix
# hosts/HL-1-MRZ-HOST-01/modules/ollama.nix (geplant)
services.ollama = {
  enable = true;
  host = "0.0.0.0";       # Erreichbar für alle VMs in vlan40
  port = 11434;
  acceleration = "cuda";   # GPU-Beschleunigung via NVIDIA CUDA
};
# Firewall: Ollama nur aus vlan40 (Server-VLAN) erreichbar
networking.firewall.allowedTCPPorts = [ 11434 ];
```

n8n-Konfiguration (Credential in n8n-UI):
- **Ollama URL:** `http://10.15.40.10:11434`
- **Kein API-Key nötig** (Ollama hat keine Auth, Firewall schützt)
- **Modell:** `mistral:7b` (Standard) oder `llama3.1:8b` (Alternative)

### 2.4 Konkrete Workflows: Ollama + n8n

#### Workflow A: KI-gestützte Dokumenten-Klassifikation für Paperless-ngx

```text
Trigger: Paperless Webhook (neues Dokument verarbeitet)
  │
  ▼
HTTP Request → Paperless API: GET /api/documents/{id}/
  → Extrahierter OCR-Text
  │
  ▼
Ollama Chat Node (mistral:7b auf HOST-01:11434):
  Prompt: "Klassifiziere dieses Dokument. Antwort als JSON:
    {kategorie, korrespondent, dokumenttyp, datum, betrag_falls_rechnung}"
  │
  ▼
Code Node: JSON parsen + Validierung
  │
  ▼
Paperless API: PATCH /api/documents/{id}/
  → Tags + Korrespondent automatisch setzen
  │
  ▼
IF betrag > 500€ → ntfy: "💰 Rechnung über €823 von Stadtwerke eingegangen"
```

**Vorteil Ollama statt Claude:** Dokumente enthalten private Daten (Rechnungen, Verträge,
persönliche Briefe) → bleiben komplett lokal auf HOST-01, kein Cloud-Upload.

#### Workflow B: Trading-Report-Analyse (Hybrid: Ollama + Claude)

```text
Trigger: Cron (täglich 22:30, nach US-Marktschluss)
  │
  ▼
HTTP Request: IBKR Flex API → XML-Report herunterladen
  │
  ▼
Code Node: XML → JSON (Positionen, P&L, Dividenden)
  │
  ▼
Ollama Chat Node (lokal, schnell, gratis):
  "Fasse zusammen: Tages-P&L, Top 3 Gewinner, Top 3 Verlierer,
   Dividenden-Eingänge. Antwort als JSON."
  │
  ▼
IF besondere Ereignisse (Dividende > 100€, Tagesverlust > 2%):
  │
  ├── JA → Anthropic Claude Node (Cloud, tiefere Analyse):
  │        "Analysiere diese Portfolio-Entwicklung. Kontext:
  │         {marktdaten}. Gibt es Handlungsbedarf?
  │         Sollte ich Positionen anpassen?"
  │        │
  │        ▼
  │       ntfy (Priority: high): Zusammenfassung + KI-Einschätzung
  │
  └── NEIN → ntfy (Priority: low):
             "📈 Portfolio-Update: +0.8% heute, keine Auffälligkeiten"
```

**Hybrid-Vorteil:** Ollama für den täglichen Standardreport (gratis, ~0.5s mit GPU),
Claude nur bei Ausreißern (bessere Analyse, aber kostet ~$0.02 pro Aufruf).

#### Workflow C: Smart-Home KI-Entscheidungen (Ollama, lokal)

```text
Trigger: Home Assistant Webhook (Energiepreis-Update alle 15min)
  │
  ▼
HTTP Request: Tibber/aWATTar API → Strompreise nächste 24h
  │
  ▼
Ollama Chat Node (mistral:7b):
  "Gegeben diese Strompreise für die nächsten 24h: [...]
   Aktueller Batterie-SOC: 45%. Wallbox-Bedarf: 30kWh.
   Wann sollte die Wallbox laden? Wann Waschmaschine starten?
   Antwort als JSON: {wallbox_start, wallbox_stop, waschmaschine_start}"
  │
  ▼
Code Node: JSON validieren + Plausibilitätsprüfung
  │
  ▼
Home Assistant API: POST /api/services/automation/trigger
  → Wallbox-Ladeplan setzen, Waschmaschinen-Timer
  │
  ▼
InfluxDB: Logge Preis + Schaltaktion als Zeitreihe
  │
  ▼
ntfy: "🔌 Wallbox lädt 02:00-05:00 (günstigster Strom: 12ct/kWh)"
```

**Vorteil Ollama:** Kein Cloud-Roundtrip, schnell (~0.3s mit GPU), privat,
keine Kosten pro Abfrage. Energiedaten bleiben lokal.

#### Workflow D: Edu-Search – KI-generierte Quizfragen aus indexiertem Material

```text
Trigger: Manuell (Webhook) oder Cron (Sonntag 18:00, Vorbereitung Woche)
  │
  ▼
PostgreSQL Node (edu-search DB, READ-ONLY):
  SELECT extracted_text, fach, klasse, thema
  FROM documents
  WHERE fach = 'Englisch' AND klasse = '10' AND thema LIKE '%Macbeth%'
  LIMIT 3
  │
  ▼
Ollama Chat Node (mistral:7b):
  "Du bist eine erfahrene Englischlehrerin. Erstelle 5 Multiple-Choice-Fragen
   zu diesem Unterrichtstext auf Niveau B2. Format als JSON:
   [{frage, optionen: [a,b,c,d], richtig: 'b', erklaerung}]"
  │
  ▼
Code Node: JSON parsen + als HTML/Markdown formatieren
  │
  ▼
E-Mail an Ina: "Hier sind 5 Quizfragen zu Macbeth für Klasse 10 (B2)"
```

**Mega-Mehrwert für Ina:** Aus den bereits indexierten und klassifizierten Materialien
automatisch Übungsaufgaben, Vokabeltests oder Zusammenfassungen generieren – ohne
dass Ina selbst mit KI interagieren muss.

#### Workflow E: Intelligente Log-Analyse bei Alerts (Ollama)

```text
Trigger: Grafana Alert Webhook ("Service X ungesund")
  │
  ▼
HTTP Request: Parseable API → Letzte 100 Log-Zeilen von Service X
  │
  ▼
Ollama Chat Node (mistral:7b):
  "Analysiere diese Server-Log-Zeilen. Was ist die wahrscheinliche
   Ursache des Problems? Schlage einen konkreten Fix vor.
   Antwort als JSON: {ursache, schweregrad, fix_vorschlag}"
  │
  ▼
IF schweregrad == "kritisch":
  │
  ├── JA → ntfy (Priority: urgent):
  │        "🔴 Grafana-Alert: PostgreSQL Connection Pool erschöpft.
  │         Fix: max_connections in postgresql.conf erhöhen."
  │
  └── NEIN → ntfy (Priority: low):
             "🟡 Grafana-Alert: Minor issue, vermutlich selbstheilend."
```

**Vorteil:** Statt nur "Service X is down" bekommt Christian eine KI-gestützte
Erstanalyse mit konkretem Lösungsvorschlag – spart Debugging-Zeit.

#### Workflow F: Wöchentliche KI-Zusammenfassung aller Systeme

```text
Trigger: Cron (Sonntag 21:00)
  │
  ▼
Parallel Queries:
  ┌─ Grafana API: Alert-Historie der Woche
  ├─ VictoriaMetrics: CPU/RAM/Disk-Trends aller Hosts
  ├─ Parseable: Error-Count pro Service
  ├─ Paperless: Neue Dokumente der Woche
  ├─ Edu-Search DB: Neue Materialien + Fehlerrate
  └─ IBKR: Wochen-P&L
  │
  ▼
Code Node: Alle Daten zu einem Kontext-String aggregieren
  │
  ▼
Ollama Chat Node (mistral:7b):
  "Du bist ein System-Administrator. Fasse diese Wochendaten zusammen.
   Hebe Probleme hervor, schlage Optimierungen vor. Maximal 200 Wörter."
  │
  ▼
ntfy/E-Mail an Christian:
  "📋 Wochenreport KW 23:
   • Infrastruktur: 2 Alerts (beide selbstheilend), Disk HOST-01 bei 72%
   • Dokumente: 12 neue in Paperless, 28 in Edu-Search indexiert
   • Portfolio: +1.8% Woche, €45 Dividenden
   • Empfehlung: ZFS Scrub auf HOST-01 planen (letzter vor 45 Tagen)"
```

### 2.5 Zusammenfassung: Ollama + n8n

| Aspekt | Bewertung |
|---|---|
| **Synergie** | ⭐⭐⭐⭐⭐ – Höchste Priorität in der gesamten Infrastruktur |
| **Voraussetzung** | Ollama muss auf HOST-01 nativ laufen (PLAN_EDU_SEARCH Phase 1) |
| **Netzwerk** | ✅ Beide in vlan40, kein Firewall-Aufwand |
| **n8n-Support** | ✅ Nativer Ollama Chat Node + Embeddings Node vorhanden |
| **Kosten** | Gratis (lokal), Claude nur als Fallback für ~$0.02/Aufruf |
| **Privatsphäre** | ✅ Alle Daten bleiben on-premise |
| **Aufwand Setup** | ~10 Minuten: Ollama-URL als Credential in n8n-UI hinterlegen |
| **GPU-Performance** | GTX 1660 SUPER: ~20-30 Tokens/s mit mistral:7b (ausreichend für Workflows) |

---

## 3. n8n ↔ Edu-Search: Detailanalyse

### 3.1 Aktueller Edu-Search-Aufbau (ohne n8n)

Die Edu-Search-Pipeline ist als **monolithischer Python-Daemon** (`indexer.py`) implementiert:

```text
Watchdog (PollingObserver, alle 60s)
    │ virtiofs (inotify unzuverlässig → Polling)
    ▼
Apache Tika (:9998, MicroVM-intern)
    │ PUT /tika → extrahierter Klartext
    ▼
Ollama auf HOST-01 (:11434, nativ, GPU)
    │ POST /api/generate → JSON-Klassifikation
    │ (Fach, Klasse, Thema, Typ, Niveau)
    ▼
PostgreSQL (:5432, MicroVM-intern)
    │ INSERT/UPDATE documents
    ▼
MeiliSearch (:7700, MicroVM-intern)
    │ POST /indexes/edu_documents/documents
    ▼
Web-UI für Ina (Nginx :8080)
```

Der Indexer bietet:

- SHA256-basiertes Hash-Caching (keine Re-Verarbeitung unveränderter Dateien)
- PostgreSQL-Transaktionen mit Rollback bei Fehlern
- MeiliSearch-Index-Konfiguration (filterbare Felder, Ranking, Typo-Toleranz)
- Strukturierter Ollama-Prompt mit JSON-Parsing und Fehlerbehandlung
- systemd-Integration (Restart, Readiness-Checks, OOM-Score, Sicherheitshärtung)
- Re-Indexierung als Oneshot-Service (`edu-reindex.service`)
- Graceful Shutdown mit Signal-Handling
- DB-Reconnect bei Verbindungsverlust

### 3.2 n8n als ERSATZ für die Core-Pipeline → ❌ Nicht empfohlen

| Aspekt | Python-Indexer (Status quo) | n8n als Pipeline-Ersatz |
|---|---|---|
| **Dateisystem-Polling** | ✅ PollingObserver für virtiofs nativ | ❌ Kein nativer virtiofs-Watcher; Cron möglich, aber kein echtes Watching |
| **Hash-basiertes Caching** | ✅ SHA256 pro Datei, überspringt Unveränderte | ⚠️ Manuell nachzubauen, fehleranfällig in n8n-Expressions |
| **Tika-Integration** | ✅ Direkte HTTP-Calls, Fehlerbehandlung, Timeout | ⚠️ HTTP-Request-Node möglich, aber weniger robuste Fehlerbehandlung |
| **Ollama-Prompt** | ✅ Prompt im Code, versioniert via Git | ⚠️ Prompt in n8n-UI; Versionierung nur über n8n-Backup |
| **PostgreSQL** | ✅ `psycopg2` mit Transaktionen + Rollback | ⚠️ n8n-PostgreSQL-Node: kein Transaktions-Support |
| **MeiliSearch** | ✅ Nativer Python-Client, Index-Settings | ❌ Kein MeiliSearch-Node; nur generische HTTP-Requests |
| **Netzwerk-Isolierung** | ✅ Alles MicroVM-intern (127.0.0.1) | ❌ n8n müsste Cross-VM auf PG/Meili/Tika zugreifen |
| **Debugging** | ✅ journald + `SyslogIdentifier` | ⚠️ n8n-UI-Debugging; kein journald |
| **Wartung** | ✅ Nix-deklarativ, reproduzierbar | ⚠️ n8n-Workflows sind Zustand in `/var/lib/n8n` |
| **Performance** | ✅ Effizient, minimaler Overhead | ❌ Node-Execution-Overhead pro Datei × tausende Dateien |
| **Batch-Verarbeitung** | ✅ Iteriert über alle Dateien in einem Prozess | ⚠️ n8n: jede Datei = separate Workflow-Execution |

**Fazit:** Der Python-Indexer ist hochspezialisiert für genau diesen Use Case. Eine Migration
nach n8n würde Komplexität hinzufügen, die Netzwerk-Isolierung aufbrechen und Robustheit
einbüßen – ohne echten Mehrwert. **Die Core-Pipeline bleibt im Python-Indexer.**

### 3.3 n8n als ERGÄNZUNG für Edu-Search → ✅ Empfohlen (selektiv)

n8n ist **nicht** als Ersatz geeignet, aber als **Orchestrator für Nebenaufgaben** wertvoll.
Diese Workflows greifen nur lesend auf die PostgreSQL-Datenbank der Edu-Search-MicroVM zu
und benötigen keine Modifikation der Core-Pipeline.

#### Workflow 1: Tägliche Benachrichtigung über neu indexierte Materialien

```text
Trigger: Cron (täglich 18:00, wenn Ina nach Hause kommt)
  │
  ▼
PostgreSQL-Node (edu-search DB, READ-ONLY):
  SELECT filename, fach, klasse, thema, typ
  FROM documents
  WHERE indexed_at > NOW() - INTERVAL '24 hours'
    AND classification_status = 'success'
  ORDER BY fach, klasse
  │
  ▼
IF-Node: Anzahl Ergebnisse > 0?
  │
  ├── JA → Code-Node: Formatiere als Markdown-Liste
  │         │
  │         ▼
  │        ntfy/E-Mail: "📚 3 neue Materialien indexiert:
  │         • Macbeth_Arbeitsblatt.docx (Englisch, Klasse 10, B2)
  │         • Vocabulario_B1.pptx (Spanisch, Klasse 8, B1)
  │         • Grammar_Test.pdf (Englisch, Klasse 7, A2)"
  │
  └── NEIN → Nichts tun (kein Spam bei leeren Tagen)
```

**Aufwand:** ~30 Min | **Nutzen:** Ina weiß sofort, wenn neue Materialien verfügbar sind

#### Workflow 2: Wöchentlicher Status-Report

```text
Trigger: Cron (Sonntag 20:00)
  │
  ▼
PostgreSQL-Node (3 Queries parallel):
  ┌─ Q1: SELECT fach, COUNT(*) FROM documents GROUP BY fach
  ├─ Q2: SELECT classification_status, COUNT(*) FROM documents GROUP BY ...
  └─ Q3: SELECT COUNT(*) FROM documents WHERE indexed_at > NOW() - INTERVAL '7 days'
  │
  ▼
Code-Node: Aggregiere zu Report
  │
  ▼
ntfy an Christian:
  "📊 Edu-Search Wochenreport:
   247 Englisch | 183 Spanisch | 34 Sonstige
   12 fehlgeschlagen (Ollama-Timeout)
   +28 diese Woche neu indexiert"
```

**Aufwand:** ~20 Min | **Nutzen:** Überblick über System-Gesundheit und Wachstum

#### Workflow 3: Fehler-Eskalation bei Pipeline-Problemen

```text
Trigger: Cron (alle 6 Stunden)
  │
  ▼
PostgreSQL-Node:
  SELECT COUNT(*) as failed FROM documents
  WHERE classification_status = 'failed'
    AND indexed_at > NOW() - INTERVAL '24 hours'
  │
  ▼
IF-Node: failed > 10?
  │
  ├── JA → ntfy (Priority: urgent):
  │        "⚠️ Edu-Search: 15 Dateien in 24h fehlgeschlagen! Ollama/Tika prüfen!"
  │
  └── NEIN → Nichts tun
```

**Aufwand:** ~15 Min | **Nutzen:** Proaktive Fehlererkennung ohne manuelles Log-Lesen

#### Workflow 4: Re-Indexierung auslösen (manuell via Webhook)

```text
Trigger: n8n Webhook (manuell aus n8n-UI klickbar)
  │
  ▼
SSH-Command-Node an HL-3-RZ-EDU-01:
  "systemctl start edu-reindex.service"
  │
  ▼
Wait-Node: 10 Minuten
  │
  ▼
PostgreSQL-Node:
  SELECT COUNT(*) FROM documents WHERE classification_status = 'success'
  │
  ▼
ntfy: "✅ Re-Index abgeschlossen: 430 Dateien erfolgreich klassifiziert"
```

**Aufwand:** ~25 Min | **Nutzen:** Bequemer Trigger nach Ollama-Modellwechsel oder Prompt-Änderung

> **Hinweis:** Workflow D aus Abschnitt 2.4 (KI-generierte Quizfragen) ist ebenfalls ein
> Edu-Search-Workflow, nutzt aber primär die Ollama-Integration und steht daher dort.

### 3.4 Voraussetzungen für n8n → Edu-Search-Anbindung

n8n (HL-3-RZ-N8N-01, 10.15.40.39) muss auf PostgreSQL der Edu-Search-MicroVM zugreifen:

1. **Firewall in `edu-search.nix`:** Port 5432 für n8n-IP freigeben
2. **PostgreSQL `listen_addresses`:** Von `127.0.0.1` auf `127.0.0.1,10.15.40.114` erweitern
3. **PostgreSQL-User:** Read-only User `n8n_reader` mit `SELECT`-Rechten auf `documents`
4. **pg_hba.conf:** `host edu_search n8n_reader 10.15.40.39/32 md5`

```nix
# In edu-search/postgresql.nix ergänzen:
services.postgresql.settings.listen_addresses = lib.mkForce "127.0.0.1";
# n8n-Zugriff wird über pg_hba geregelt – listen bleibt intern,
# n8n greift über die MicroVM-IP zu (10.15.40.114:5432)
services.postgresql.authentication = lib.mkAfter ''
  host edu_search n8n_reader 10.15.40.39/32 md5
'';
```

---

## 4. n8n ↔ Aktive MicroVMs: Integrationsbewertung

### Bewertungsübersicht

| MicroVM | Synergie | Begründung | Top-Use-Case |
|---|---|---|---|
| **Ollama (HOST-01 nativ)** | ⭐⭐⭐⭐⭐ | Zentrales KI-Backend für alle Workflows | KI-Orchestrator (siehe Abschnitt 2) |
| **Paperless-ngx** | ⭐⭐⭐⭐⭐ | REST-API + Ollama = KI-Auto-Tagging | Dokumenten-Klassifikation (Workflow A) |
| **IBKR Flex / IB Gateway** | ⭐⭐⭐⭐⭐ | Ersetzt Shell-Skript, ermöglicht KI-Analyse | Portfolio-Report (Workflow B) |
| **Home Assistant** | ⭐⭐⭐⭐ | Komplexe Automationen jenseits HA-Möglichkeiten | Strompreis-Optimierung (Workflow C) |
| **Edu-Search** | ⭐⭐⭐⭐ | Ergänzung (nicht Ersatz!) der Core-Pipeline | Benachrichtigungen + Quizfragen (Workflows 1-4, D) |
| **Grafana + Parseable** | ⭐⭐⭐ | Alert-Eskalation mit KI-Analyse | Log-Analyse (Workflow E) |
| **Forgejo** | ⭐⭐⭐ | Webhook-basierte CI/CD-Orchestrierung | Deployment-Notifications, Auto-Issues |
| **VictoriaMetrics + InfluxDB** | ⭐⭐⭐ | Metrik-Aggregation + KI-Trend-Analyse | Wochenreport (Workflow F) |
| **Linkwarden** | ⭐⭐ | Auto-Import + Kategorisierung | Bookmark-Auto-Tagging |
| **Samba / Syncthing** | ⭐⭐ | Dateiänderungs-Notifications | Speicherplatz-Monitoring |
| **Node-RED** | ⭐⭐ | Überlappende Fähigkeiten (IoT bleibt bei Node-RED) | Brücke für nicht-IoT-Workflows |
| **Mosquitto** | ⭐⭐ | n8n hat MQTT-Node, aber Node-RED ist besser dafür | MQTT→HTTP-Brücke für externe APIs |
| **AdGuard Home** | ⭐ | Wenig Automatisierungsbedarf | DNS-Statistik-Reports |
| **Ente Photos** | ⭐ | Limitierte API | Speicherplatz-Alerts |
| **Vaultwarden** | ⭐ | Sicherheitskritisch, sollte nicht automatisiert werden | Keine Empfehlung |
| **Kanidm** | ⭐ | SSO-Infrastruktur, nicht automatisierbar | Keine Empfehlung |
| **S3 (Garage)** | ⭐ | Backend-Storage, kein Frontend-Use-Case | Bucket-Statistiken |
| **Homepage** | ⭐ | Statisches Dashboard | Keine Empfehlung |
| **UniFi** | ⭐ | UniFi hat eigene Automatisierung | Netzwerk-Alerts (optional) |
| **Powermeter** | ⭐⭐ | Daten über HA/InfluxDB erreichbar | Stromverbrauchs-Anomalien |

### 4.1 Paperless-ngx → ⭐⭐⭐⭐⭐ (Höchste Synergie neben Ollama)

Paperless hat eine vollständige REST-API und verarbeitet bereits OCR-Text.
n8n + Ollama können das Tagging revolutionieren.

**Bereits vorhanden:** Paperless OAuth2 via Kanidm, Webhook-Support, REST-API.

```text
Workflow: "KI-Auto-Tagging für neue Dokumente"
───────────────────────────────────────────────
Trigger: Paperless Webhook (neues Dokument fertig verarbeitet)
  │
  ▼
HTTP Request: Paperless API → GET /api/documents/{id}/
  → OCR-Text + aktuelle Tags
  │
  ▼
Ollama Chat Node (mistral:7b, lokal):
  "Analysiere dieses Dokument. Bestimme:
   1. Kategorie: Rechnung/Vertrag/Brief/Behörde/Versicherung/Steuer/Sonstiges
   2. Korrespondent: Wer hat das geschrieben?
   3. Betrag (falls Rechnung): in EUR
   4. Fälligkeitsdatum (falls vorhanden)
   Antwort als JSON."
  │
  ▼
HTTP Request: Paperless API → PATCH /api/documents/{id}/
  → Tags setzen, Korrespondent zuweisen
  │
  ▼
IF Kategorie == "Rechnung" AND Betrag > 200:
  → ntfy: "💰 Neue Rechnung: €823 von Stadtwerke, fällig am 15.07."
```

**Voraussetzungen:**
- Paperless API-Token als n8n-Credential
- Paperless Webhook-URL konfigurieren (POST an `https://n8n.czichy.com/webhook/paperless`)
- Ollama erreichbar (HOST-01:11434)

### 4.2 IBKR Flex / IB Gateway → ⭐⭐⭐⭐⭐

Der aktuelle `ibkr-flex.nix` ist ein einfaches Shell-Skript mit Cron-Timer.
n8n kann das komplett ersetzen und um KI-Analyse erweitern.

**Aktuell (`ibkr-flex.nix`):** Shell-Skript → Download XML → Sortiere in Ordner → Healthcheck-Ping

**Mit n8n:**

```text
Workflow: "IBKR Flex Download + KI-Analyse + Metriken"
──────────────────────────────────────────────────────
Trigger: Cron (täglich 22:30)
  │
  ▼
HTTP Request: IBKR Flex API
  → Token aus n8n-Credential (kein age-Secret nötig)
  → XML-Report herunterladen
  │
  ▼
Code Node: XML → JSON
  → Positionen, Tages-P&L, Dividenden, Trades extrahieren
  │
  ▼
Parallel:
  ┌─ HTTP Request: VictoriaMetrics API
  │    → NAV, Cash, Margin als Zeitreihe schreiben
  │    → In Grafana als Dashboard sichtbar
  │
  ├─ Ollama Chat Node: Tages-Zusammenfassung
  │    → "Top Gewinner: MSFT +2.3%, Verlierer: TSLA -1.8%"
  │
  └─ IF Dividende eingegangen:
       → InfluxDB: Dividende loggen
       → ntfy: "💰 Dividende: $45 von AAPL"
  │
  ▼
ntfy: "📈 Portfolio-Update: +0.8% ($1,234). NAV: $154,320"
```

**Voraussetzungen:**
- IBKR Flex Token als n8n-Credential
- VictoriaMetrics-Zugriff (schon in vlan40)
- Optional: ibkr-flex MicroVM kann langfristig entfallen

### 4.3 Home Assistant → ⭐⭐⭐⭐

HA hat eine mächtige REST-API. n8n ergänzt HA dort, wo **externe APIs + KI-Logik** nötig sind.
IoT-Basisautomationen bleiben in HA/Node-RED.

```text
Workflow: "Intelligente Anwesenheitserkennung + Energieoptimierung"
──────────────────────────────────────────────────────────────────
Trigger: HA Webhook (Tür-Sensor + Bewegungsmelder-Kombination)
  │
  ▼
HTTP Request: HA API → Aktueller Zustand aller Sensoren
  (Tür, Bewegungsmelder, Handy-GPS, Licht-Status)
  │
  ▼
Ollama Chat Node:
  "Gegeben: Tür offen seit 5min, kein Bewegungsmelder aktiv,
   Handy-GPS > 500m, Lichter an. Ist jemand zuhause?
   Antwort: {zuhause: true/false, confidence: 0-100, aktion}"
  │
  ▼
IF zuhause == false AND confidence > 80:
  │
  ▼
HA API: POST /api/services/scene/turn_on
  → Szene "Niemand zuhause" (Heizung runter, Lichter aus)
  │
  ▼
ntfy: "🏠 Automatisch auf Abwesenheits-Modus geschaltet"
```

**Abgrenzung zu Node-RED:** Node-RED bleibt für direkte IoT-Flows (MQTT, Zigbee, einfache
Automationen). n8n übernimmt Flows, die KI, externe APIs oder Cross-Service-Logik brauchen.

### 4.4 Grafana + Parseable → ⭐⭐⭐

```text
Workflow: "Alert-Eskalation mit KI-Erstanalyse"
────────────────────────────────────────────────
Trigger: Grafana Alert Webhook
  │
  ▼
Code Node: Alert-Payload parsen (Service-Name, Metrik, Schwellwert)
  │
  ▼
HTTP Request: Parseable API → Letzte 100 Log-Zeilen des betroffenen Service
  │
  ▼
Ollama Chat Node:
  "Analysiere diese Logs. Ursache? Schweregrad? Fix-Vorschlag?"
  │
  ▼
Switch Node (nach Schweregrad):
  ├── kritisch → ntfy (urgent) + Forgejo Issue erstellen
  ├── warnung  → ntfy (normal)
  └── info     → Nur loggen, kein Alert
```

### 4.5 Forgejo → ⭐⭐⭐

```text
Workflow 1: "Auto-Issue bei Monitoring-Alert"
─────────────────────────────────────────────
Trigger: Von Workflow 4.4 (Alert-Eskalation, Schweregrad "kritisch")
  │
  ▼
Forgejo API: POST /api/v1/repos/christian/nixos/issues
  → Title: "🔴 Alert: {service} down seit {dauer}"
  → Body: KI-Analyse + Log-Auszug + Fix-Vorschlag

Workflow 2: "Deployment-Notification"
─────────────────────────────────────
Trigger: Forgejo Webhook (Push auf main-Branch)
  │
  ▼
IF Commit-Message enthält "[deploy]":
  → ntfy: "🚀 Neuer NixOS-Commit: {message}"
```

### 4.6 Linkwarden → ⭐⭐

```text
Workflow: "Auto-Kategorisierung neuer Bookmarks"
────────────────────────────────────────────────
Trigger: Cron (stündlich) oder Linkwarden Webhook
  │
  ▼
Linkwarden API: GET /api/v1/links?sort=-createdAt&take=10
  → Neue unkategorisierte Bookmarks
  │
  ▼
Ollama Chat Node: "Kategorisiere diese URLs:
  {url_1}: ..., {url_2}: ...
  Antwort als JSON: [{url, kategorie, tags}]"
  │
  ▼
Linkwarden API: PUT → Tags + Collection zuweisen
```

### 4.7 Node-RED / Mosquitto → ⭐⭐

n8n und Node-RED haben überlappende Fähigkeiten. Klare Abgrenzung:

| Bereich | Tool | Begründung |
|---|---|---|
| IoT-Automationen (MQTT, Zigbee) | **Node-RED** | Besser für Echtzeit-IoT, direkter MQTT-Support |
| Sensordaten-Verarbeitung | **Node-RED** | Läuft auf HOST-03 nah an Mosquitto/HA |
| KI-gestützte Workflows | **n8n** | Native Ollama/Claude-Nodes |
| Cross-Service-Orchestrierung | **n8n** | Bessere API-Integration, Credentials-Management |
| Externe APIs (IBKR, Tibber, etc.) | **n8n** | HTTP-Request-Node + OAuth2-Support |
| Dashboard-Notifications | **n8n** | ntfy/E-Mail-Integration |

n8n kann optional als MQTT-Client an Mosquitto andocken (n8n hat einen MQTT-Trigger-Node),
um IoT-Events als Auslöser für KI-Workflows zu nutzen. Beispiel:

```text
Mosquitto (MQTT) → n8n MQTT-Trigger → Ollama → ntfy
"Stromzähler meldet ungewöhnlich hohen Verbrauch um 3:00 nachts"
→ KI: "Wahrscheinlich Kühlschrank-Kompressor defekt. Prüfen!"
```

### 4.8 Samba / Syncthing → ⭐⭐

```text
Workflow: "Speicherplatz-Monitoring + Auto-Warnung"
───────────────────────────────────────────────────
Trigger: Cron (täglich 08:00)
  │
  ▼
SSH-Command an HOST-01: "zpool list -Hp storage"
  → Verwendet, Frei, Fragmentierung
  │
  ▼
IF Belegung > 85%:
  │
  ▼
Ollama: "Analysiere diese ZFS-Pool-Statistiken. Welche Datasets
  wachsen am schnellsten? Wann ist der Pool voll (Prognose)?"
  │
  ▼
ntfy (Priority: high):
  "💾 Storage-Pool bei 87%! Prognose: voll in ~45 Tagen.
   Größte Datasets: immich (234GB), paperless (89GB)"
```

### 4.9 Niedrige Synergie (⭐) – Keine Empfehlung

| MicroVM | Warum nicht? |
|---|---|
| **Vaultwarden** | Sicherheitskritisch. Automatisierung = Angriffsfläche. Keine API-Calls durch n8n. |
| **Kanidm** | SSO-Infrastruktur. Änderungen nur manuell/deklarativ via Nix. |
| **S3 (Garage)** | Backend-Storage ohne Frontend-Use-Case. Bucket-Statistiken über Grafana abbildbar. |
| **Homepage** | Statisches Dashboard, keine Automatisierung nötig. |
| **UniFi** | Hat eigene Automatisierung/Alerting. n8n-Integration wäre Overhead. |
| **Ente Photos** | Sehr limitierte API, keine sinnvollen Automations-Trigger. |
| **AdGuard Home** | Funktioniert autonom. Maximal: DNS-Statistik-Report (kaum Mehrwert). |

---

## 5. Priorisierte Umsetzungsreihenfolge

### Phase 0: Voraussetzung (muss zuerst erledigt werden)

| # | Aufgabe | Abhängigkeit | Aufwand |
|---|---|---|---|
| 0.1 | Ollama nativ auf HOST-01 mit GPU (PLAN_EDU_SEARCH Phase 1) | NVIDIA-Treiber + CUDA | 1 Wochenende |
| 0.2 | Ollama-Credential in n8n-UI anlegen (`http://10.15.40.10:11434`) | 0.1 | 5 Minuten |
| 0.3 | Anthropic-Credential in n8n-UI verifizieren (API-Key schon da) | – | 5 Minuten |

### Phase 1: Quick Wins (sofort nach Ollama-Setup)

| # | Workflow | Synergie | Aufwand | Nutzen |
|---|---|---|---|---|
| 1.1 | Wöchentliche KI-Zusammenfassung aller Systeme (Workflow F) | ⭐⭐⭐⭐⭐ | ~45 Min | Überblick über gesamte Infrastruktur |
| 1.2 | IBKR Tages-Report mit KI-Zusammenfassung (Workflow B) | ⭐⭐⭐⭐⭐ | ~60 Min | Ersetzt Shell-Skript, KI-Analyse gratis |
| 1.3 | Paperless KI-Auto-Tagging (Workflow A) | ⭐⭐⭐⭐⭐ | ~45 Min | Automatisches Dokumenten-Tagging |

### Phase 2: Edu-Search-Ergänzungen (nach Edu-Search Go-Live)

| # | Workflow | Synergie | Aufwand | Nutzen |
|---|---|---|---|---|
| 2.1 | Edu-Search Benachrichtigungen für Ina (Workflow 1) | ⭐⭐⭐⭐ | ~30 Min | Ina wird über neue Materialien informiert |
| 2.2 | Edu-Search Wochenreport (Workflow 2) | ⭐⭐⭐⭐ | ~20 Min | System-Gesundheit im Blick |
| 2.3 | Edu-Search Fehler-Eskalation (Workflow 3) | ⭐⭐⭐⭐ | ~15 Min | Proaktive Fehlererkennung |
| 2.4 | KI-generierte Quizfragen (Workflow D) | ⭐⭐⭐⭐ | ~60 Min | Mega-Mehrwert für Ina |

### Phase 3: Smart Home + Monitoring (optional, laufend)

| # | Workflow | Synergie | Aufwand | Nutzen |
|---|---|---|---|---|
| 3.1 | Smart-Home Strompreis-Optimierung (Workflow C) | ⭐⭐⭐⭐ | ~60 Min | Energiekosten senken |
| 3.2 | Alert-Eskalation mit KI-Log-Analyse (Workflow E) | ⭐⭐⭐ | ~45 Min | Schnellere Problemdiagnose |
| 3.3 | Forgejo Auto-Issues bei Alerts | ⭐⭐⭐ | ~30 Min | Automatische Dokumentation |
| 3.4 | Speicherplatz-Monitoring (Workflow 4.8) | ⭐⭐ | ~20 Min | Rechtzeitige Warnung |

### Gesamtaufwand-Schätzung

| Phase | Aufwand | Zeitrahmen |
|---|---|---|
| Phase 0 | ~1 Wochenende | Vor allem anderen |
| Phase 1 | ~2.5 Stunden | 1 Abend nach Phase 0 |
| Phase 2 | ~2 Stunden | Nach Edu-Search Go-Live |
| Phase 3 | ~2.5 Stunden | Laufend, nach Bedarf |
| **Gesamt** | **~1 Wochenende + 7 Stunden** | **Verteilt über 3-4 Wochen** |

---

## 6. Technische Voraussetzungen

### 6.1 Netzwerk (vlan40)

Alle relevanten Services liegen bereits in vlan40. n8n (10.15.40.39) kann erreichen:

| Ziel | IP | Port | Status |
|---|---|---|---|
| Ollama (HOST-01 nativ, geplant) | 10.15.40.10 | 11434 | 🔜 Nach PLAN_EDU_SEARCH Phase 1 |
| Edu-Search PostgreSQL | 10.15.40.114 | 5432 | ⚠️ Firewall + pg_hba anpassen |
| Paperless-ngx | 10.15.40.16 | 28981 | ✅ Erreichbar |
| Grafana | 10.15.40.111 | 3000 | ✅ Erreichbar |
| VictoriaMetrics | 10.15.40.112 | 8428 | ✅ Erreichbar |
| InfluxDB | 10.15.40.12 | 8086 | ✅ Erreichbar |
| Parseable | 10.15.40.18 | 8000 | ✅ Erreichbar |
| Forgejo | 10.15.40.14 | 3000 | ✅ Erreichbar |
| Home Assistant | 10.15.40.36 | 8123 | ✅ Erreichbar |
| Linkwarden | 10.15.40.x | 3000 | ✅ Erreichbar |
| Mosquitto (MQTT) | 10.15.40.33 | 1883 | ✅ Erreichbar |

### 6.2 n8n-Credentials (in n8n-UI zu konfigurieren)

| Credential | Typ | Quelle |
|---|---|---|
| Ollama | URL: `http://10.15.40.10:11434` | Kein Auth nötig (Firewall schützt) |
| Anthropic Claude | API-Key | Bereits als `n8n-anthropic-api-key` Secret vorhanden |
| Paperless-ngx | API-Token | In Paperless-Admin generieren |
| Forgejo | API-Token | In Forgejo-Settings generieren |
| Home Assistant | Long-Lived Access Token | In HA-Profil generieren |
| PostgreSQL (edu-search) | Host/Port/User/Pass | Read-only User `n8n_reader` anlegen |
| IBKR Flex | Token + Query-ID | Aus bestehender `ibkr-flex.nix` Secret migrieren |
| ntfy | URL + Auth | `https://ntfy.czichy.com`, bestehende Credentials |
| VictoriaMetrics | URL | `http://10.15.40.112:8428`, kein Auth |

### 6.3 Nix-Änderungen

Minimale Änderungen an bestehenden MicroVMs für n8n-Zugriff:

```nix
# edu-search/postgresql.nix – n8n Read-Only-Zugriff
services.postgresql.settings.listen_addresses = "127.0.0.1,10.15.40.114";
networking.firewall.allowedTCPPorts = [ 5432 ]; # Für n8n
services.postgresql.authentication = lib.mkAfter ''
  host edu_search n8n_reader 10.15.40.39/32 md5
'';

# Optional: Paperless Webhook-URL in paperless settings
# services.paperless.settings.PAPERLESS_POST_CONSUME_SCRIPT = ...
# (Alternativ: Paperless-Webhook über n8n-Community-Node)
```

### 6.4 ai.nix Refactoring nach Ollama-Migration

Sobald Ollama nativ auf HOST-01 läuft:

```nix
# ai.nix – Reduzierte MicroVM: nur noch Open-WebUI
{
  microvm.mem = 1024 * 2;  # Statt 16GB nur noch 2GB für Open-WebUI
  microvm.vcpu = 2;         # Statt 20 nur noch 2

  # Ollama ENTFERNT – läuft nativ auf HOST-01
  # services.ollama.enable = false;

  services.open-webui = {
    enable = true;
    environment = {
      # Zeigt auf nativen Ollama-Service auf HOST-01
      OLLAMA_BASE_URL = "http://10.15.40.10:11434";
    };
  };
}
# Ersparnis: ~14GB RAM, ~18 vCPUs
```

---

## 7. Offene Fragen & Risiken

### Offene Fragen

| # | Frage | Auswirkung | Priorität |
|---|---|---|---|
| 1 | Soll die ai.nix MicroVM nach Ollama-Migration komplett entfernt oder für Open-WebUI behalten werden? | RAM-Planung HOST-01 | Mittel |
| 2 | Soll n8n langfristig die ibkr-flex MicroVM ersetzen (Shell-Skript → n8n Workflow)? | Eine MicroVM weniger | Niedrig |
| 3 | Wie werden n8n-Workflows versioniert? Export als JSON ins Git-Repo? | Reproduzierbarkeit | Hoch |
| 4 | Rate-Limiting für Anthropic Claude API? Budget-Obergrenze pro Monat? | Kostenkontrolle | Mittel |
| 5 | Soll n8n Community-Nodes nutzen dürfen (z.B. Paperless-Node)? | Sicherheit vs. Komfort | Niedrig |
| 6 | Ollama-Modellwahl: `mistral:7b` vs. `llama3.1:8b`? Beide passen in 6GB VRAM. | Qualität der KI-Outputs | Mittel |

### Risiken

| Risiko | Schwere | Wahrscheinlichkeit | Mitigation |
|---|---|---|---|
| n8n wird Single Point of Failure für Automationen | Mittel | Niedrig | Core-Services (Edu-Search-Pipeline, HA-Automationen) sind unabhängig von n8n. n8n ist nur Ergänzung. |
| Ollama-GPU-Konkurrenz zwischen Edu-Search-Indexer und n8n-Workflows | Mittel | Mittel | Ollama queued Requests automatisch. Bei Engpass: n8n-Workflows auf Off-Peak-Zeiten (nachts) legen. |
| Anthropic-API-Kosten steigen bei häufiger Nutzung | Niedrig | Niedrig | "Ollama first"-Strategie: Claude nur als Fallback. Budget-Alert in n8n wenn > $10/Monat. |
| n8n-Workflows sind Zustand (nicht deklarativ wie Nix) | Mittel | Hoch | Regelmäßiger JSON-Export der Workflows ins Git-Repo. Restic-Backup bereits konfiguriert. |
| Sicherheitslücke durch n8n-Zugriff auf viele Services | Mittel | Niedrig | n8n nur in vlan40 (kein Internet-Zugriff außer Anthropic API). Credentials verschlüsselt mit `n8n-encryption-key`. Read-only DB-User wo möglich. |
| GTX 1660 SUPER VRAM (6GB) reicht nicht für größere Modelle | Niedrig | Niedrig | mistral:7b (~4.1GB) und llama3.1:8b (~4.7GB) passen. Für größere Modelle: Claude als Fallback. |

---

## 8. Fazit

### Kernaussagen

1. **Ollama + n8n ist der stärkste Integrationspunkt** der gesamten Infrastruktur (⭐⭐⭐⭐⭐).
   Sobald Ollama nativ auf HOST-01 mit GPU läuft, wird n8n zum zentralen KI-Orchestrator mit
   zwei komplementären Backends (Ollama lokal + Claude Cloud).

2. **Edu-Search Core-Pipeline bleibt im Python-Indexer** (❌ kein n8n-Ersatz). Der spezialisierte
   Daemon mit virtiofs-Polling, Hash-Caching und PostgreSQL-Transaktionen ist n8n überlegen.
   n8n ergänzt mit Benachrichtigungen, Reports und KI-generierten Quizfragen (✅).

3. **Paperless-ngx und IBKR Flex** profitieren am stärksten von n8n + Ollama (⭐⭐⭐⭐⭐):
   KI-Auto-Tagging für Dokumente (lokal, privat) und tägliche Portfolio-Analysen mit
   Hybrid-Strategie (Ollama Standard, Claude bei Ausreißern).

4. **Home Assistant** gewinnt KI-gestützte Entscheidungsfähigkeit für Energieoptimierung
   und intelligente Anwesenheitserkennung – ohne Cloud-Abhängigkeit (⭐⭐⭐⭐).

5. **Gesamtaufwand:** ~1 Wochenende (Ollama-Setup) + ~7 Stunden (Workflows), verteilt über
   3-4 Wochen. Der ROI ist hoch: automatische Dokumenten-Klassifikation, Portfolio-Reports
   und Quizfragen-Generierung für Ina allein rechtfertigen den Aufwand.

### Nächster Schritt

→ **PLAN_EDU_SEARCH Phase 1 umsetzen** (NVIDIA-Treiber + Ollama nativ auf HOST-01).
   Danach sofort Phase 1 Quick Wins (Abschnitt 5): Ollama-Credential in n8n anlegen,
   IBKR-Report und Paperless-Auto-Tagging als erste Workflows.