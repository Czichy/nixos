# 🎓 Edu-Search – Implementierungsplan

## Unterrichtsmaterial-Suchsystem für Ina (Lehrerin Englisch/Spanisch)

> **Ziel:** Ina kann über eine einfache Weboberfläche im Browser alle ihre Unterrichtsmaterialien
> durchsuchen – nach Fach, Klasse, Thema, Typ und Freitext. Die Originaldateien auf dem NAS
> bleiben unverändert. Das System indexiert automatisch bei Änderungen.

---

## Inhaltsverzeichnis

1. [Architektur-Übersicht](#1-architektur-übersicht)
2. [Entscheidung: Ollama auf HOST-01 vs. MicroVM](#2-entscheidung-ollama-auf-host-01-vs-microvm)
3. [Komponenten-Details](#3-komponenten-details)
4. [Datei- und Verzeichnisstruktur im Nix-Repo](#4-datei--und-verzeichnisstruktur-im-nix-repo)
5. [Phase 1 – Fundament](#5-phase-1--fundament-12-wochenenden)
6. [Phase 2 – Suche & Indexierung](#6-phase-2--suche--indexierung-1-wochenende)
7. [Phase 3 – Web-UI für Ina](#7-phase-3--web-ui-für-ina-1-wochenende)
8. [Phase 4 – Backup & Monitoring](#8-phase-4--backup--monitoring)
9. [Netzwerk & Globals](#9-netzwerk--globals)
10. [Offene Fragen & Risiken](#10-offene-fragen--risiken)

---

## 1. Architektur-Übersicht

```text
┌──────────────────────────────────────────────────────────────────────────┐
│                          HL-1-MRZ-HOST-01                                │
│            (AMD Ryzen Matisse, 64GB RAM, GTX 1660 SUPER 6GB, ZFS)        │
│                                                                          │
│  ┌───────────────────────────────────────────────┐                       │
│  │       Direkt auf HOST-01 (nativ)              │                       │
│  │                                               │                       │
│  │  ● NVIDIA-Treiber + CUDA Toolkit              │                       │
│  │  ● Ollama Service (GPU-beschleunigt)          │                       │
│  │    - Port 11434 (nur localhost + vlan40)       │                       │
│  │    - Modell: mistral:7b oder llama3.1:8b      │                       │
│  │  ● Open-WebUI (optional, Port 11222)          │                       │
│  │                                               │                       │
│  └───────────────────────────────────────────────┘                       │
│                            │ HTTP :11434                                  │
│                            ▼                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │              MicroVM: "edu-search"                                  │ │
│  │              (HL-3-RZ-EDU-01, vlan40, .114)                         │ │
│  │                                                                     │ │
│  │  ┌──────────┐  ┌───────────┐  ┌─────────────┐  ┌────────────────┐ │ │
│  │  │ Apache   │  │PostgreSQL │  │ MeiliSearch  │  │ Caddy / Nginx  │ │ │
│  │  │ Tika     │  │  (Meta-   │  │ (Volltext-   │  │ + Web-UI (SPA) │ │ │
│  │  │ Server   │  │   daten)  │  │   suche)     │  │                │ │ │
│  │  │ :9998    │  │  :5432    │  │  :7700       │  │  :8080         │ │ │
│  │  └────┬─────┘  └─────┬────┘  └──────┬──────┘  └────────────────┘ │ │
│  │       │               │              │                             │ │
│  │       └───────┬───────┘──────────────┘                             │ │
│  │               │                                                    │ │
│  │  ┌────────────▼──────────────────────────────────────────────┐     │ │
│  │  │  Python Indexer Service (edu-indexer.service)              │     │ │
│  │  │  - Watchdog: überwacht NAS-Shares via virtiofs            │     │ │
│  │  │  - Tika: Textextraktion aus DOCX/PDF/PPTX/ODT/etc.       │     │ │
│  │  │  - Ollama (HOST-01 via HTTP): KI-Klassifikation           │     │ │
│  │  │  - PostgreSQL: Metadaten speichern                        │     │ │
│  │  │  - MeiliSearch: Volltext + Metadaten indexieren            │     │ │
│  │  └───────────────────────────────────────────────────────────┘     │ │
│  │                          │ virtiofs                                 │ │
│  └──────────────────────────┼─────────────────────────────────────────┘ │
│                             │                                            │
│  ┌──────────────────────────▼────────────────────────────────────────┐   │
│  │  ZFS storage Pool – NAS Shares (read-only für edu-search)        │   │
│  │  /shared/shares/users/ina/schule/     ← Schulunterlagen Sync     │   │
│  │  /storage/shares/bibliothek/          ← Bibliothek               │   │
│  │  /storage/shares/dokumente/           ← Dokumente                │   │
│  └───────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
           │
           │ HTTPS (Caddy Reverse Proxy auf HOST-02)
           ▼
     ┌──────────────┐
     │  Browser     │   https://edu.czichy.com
     │  (Ina/PC)    │   Suchfeld + Filter + Ergebnisliste
     └──────────────┘
```

### Datenfluss bei neuer/geänderter Datei

```text
 Ina speichert Datei auf NAS (Samba)
        │
        ▼
 Watchdog erkennt Änderung (inotify/polling via virtiofs)
        │
        ▼
 Datei → Apache Tika HTTP API (:9998)
        │   PUT /tika  →  extrahierter Klartext
        ▼
 Extrahierter Text → Ollama HTTP API (HOST-01:11434)
        │   POST /api/generate
        │   Prompt: "Klassifiziere als JSON: Fach, Klasse, Thema, Typ, Niveau"
        │   Antwort: {"fach":"Englisch","klasse":"10","thema":"Macbeth","typ":"Arbeitsblatt","niveau":"B2"}
        ▼
 Metadaten + Pfad → PostgreSQL (INSERT/UPDATE documents)
        │
        ▼
 Dokument + Metadaten → MeiliSearch (POST /indexes/edu_documents/documents)
        │
        ▼
 Ina sucht im Browser → MeiliSearch liefert Treffer → Klick öffnet Datei via smb://
```

---

## 2. Entscheidung: Ollama auf HOST-01 vs. MicroVM

### ⚡ Klare Empfehlung: **Ollama DIREKT auf HOST-01**

| Kriterium | Direkt auf HOST-01 | MicroVM |
|---|---|---|
| **GPU-Zugriff** | ✅ Nativ via CUDA | ❌ Kein GPU-Passthrough in microvm.nix¹ |
| **Performance** | ✅ Volle GPU-Leistung | ❌ Nur CPU (extrem langsam für LLM) |
| **Komplexität** | ✅ Einfache NixOS-Konfiguration | ⚠️ VFIO-Passthrough sehr aufwändig |
| **RAM-Overhead** | ✅ Kein VM-Overhead | ❌ +2GB für VM-Kernel etc. |
| **Bereits konfiguriert?** | ❌ Nein (ai.nix ist MicroVM) | ⚠️ ai.nix existiert, aber ohne GPU |
| **Wartung** | ✅ Einfach | ⚠️ VFIO-Gruppen, Treiberprobleme |

> ¹ `microvm.nix` (astro/microvm.nix) unterstützt **keine PCI-Passthrough-Geräte** für QEMU-Gäste
> im Standard-Setup. GPU-Passthrough erfordert vollständiges VFIO mit `vfio-pci`-Treiber-Binding,
> IOMMU-Gruppen-Isolation und manuelles QEMU-Kommando – das widerspricht dem microvm.nix-Ansatz.

### Konsequenz für die bestehende `ai.nix` MicroVM

Die aktuelle `ai.nix` Guest-Konfiguration betreibt Ollama **ohne GPU** in einer MicroVM mit 16GB RAM
und 20 vCPUs. Das ist für LLM-Inference auf CPU extrem langsam. Der Refactoring-Plan:

- **Ollama** → aus MicroVM raus, wird zum nativen Service auf HOST-01
- **Open-WebUI** → kann optional in der MicroVM bleiben, greift dann auf `http://10.15.40.10:11434` zu
- Die MicroVM `ai` wird **entweder entfernt** oder nur noch für Open-WebUI genutzt (deutlich weniger RAM)

---

## 3. Komponenten-Details

### 3.1 NVIDIA-Treiber + CUDA (HOST-01, nativ)

| Eigenschaft | Wert |
|---|---|
| **NixOS-Module** | `hardware.nvidia`, `hardware.graphics` (ehemals opengl) |
| **Paket** | `config.boot.kernelPackages.nvidiaPackages.stable` |
| **Kernel-Modul** | `nvidia` in `boot.initrd.kernelModules` |
| **Persistenz** | Keine (Treiber im Nix-Store) |
| **Backup nötig?** | ❌ Nein |

> **✅ BESTÄTIGT:** GPU ist eine **NVIDIA GeForce GTX 1660 SUPER** (TU116, 6GB VRAM)
> an PCI-Adresse `2d:00.0`. Turing-Architektur → `nvidiaPackages.stable` (proprietär) ist
> der richtige Treiberast. `open = false` da das Open-Source-Kernel-Modul TU116 nicht
> vollständig unterstützt. System hat **64GB RAM** (AMD Ryzen Matisse/Vermeer).

### 3.2 Ollama (HOST-01, nativ)

| Eigenschaft | Wert |
|---|---|
| **NixOS-Modul** | `services.ollama` |
| **Port** | `11434` |
| **Bind** | `0.0.0.0` (Firewall beschränkt auf vlan40) |
| **GPU-Option** | `services.ollama.acceleration = "cuda"` |
| **Modell** | `mistral:7b` (gut für strukturierte JSON-Extraktion, ~4.1GB VRAM) |
| **Alt. Modelle** | `llama3.1:8b` (~4.7GB, passt noch in 6GB VRAM), `gemma2:9b` (zu groß für 6GB!) |
| **VRAM-Limit** | 6GB (GTX 1660 SUPER) → max. ~7B-8B Parameter-Modelle |
| **Daten** | `/var/lib/private/ollama` (Modelle, ~5-8 GB pro Modell auf Disk) |
| **Persistenz** | `environment.persistence."/state"` (impermanence) |
| **Backup nötig?** | ⚠️ Optional – Modelle können jederzeit `ollama pull` werden |

### 3.3 Apache Tika Server (MicroVM edu-search)

| Eigenschaft | Wert |
|---|---|
| **Paket** | `fetchurl` des offiziellen `tika-server-standard-X.Y.Z.jar` (~80MB) |
| **Betrieb** | Eigener `systemd`-Service im HTTP-Server-Modus (`java -jar`) |
| **Port** | `9998` (Standard Tika Server Port) |
| **Bind** | `127.0.0.1` (nur MicroVM-intern) |
| **JVM** | `pkgs.jre_minimal` (oder `pkgs.jdk21_headless`), Heap: `-Xmx512m` |
| **Unterstützt** | DOCX, PPTX, PDF, ODT, ODS, XLSX, MP3/MP4 (Meta), HTML, TXT, RTF |
| **Python-Client** | `python3Packages.tika-client` (in nixpkgs vorhanden) als Alternative |
| **Daten** | Stateless – kein persistenter Zustand |
| **Backup nötig?** | ❌ Nein |

> **✅ GEKLÄRT:** `pkgs.apacheTika` existiert NICHT in nixpkgs. Verfügbar sind:
> - `python3Packages.tika` (3.1.0) – Python-Binding, startet Tika-Server selbst
> - `python3Packages.tika-client` (0.10.0) – Client für laufenden Tika-Server
> - Wir verwenden `fetchurl` für das offizielle Apache Tika Server JAR + `jdk21_headless`

### 3.4 PostgreSQL (MicroVM edu-search)

| Eigenschaft | Wert |
|---|---|
| **NixOS-Modul** | `services.postgresql` |
| **Version** | 16 (aktuell in nixpkgs-unstable) |
| **Port** | `5432` |
| **Bind** | `127.0.0.1` |
| **Datenbank** | `edu_search` |
| **Tabelle** | `documents` (siehe Schema unten) |
| **Persistenz** | `/persist/var/lib/postgresql` (impermanence) |
| **Backup nötig?** | ✅ **Ja** – enthält alle KI-Klassifikationsergebnisse |

**Schema `documents`:**

```sql
CREATE TABLE documents (
    id              SERIAL PRIMARY KEY,
    filepath        TEXT UNIQUE NOT NULL,        -- Relativer Pfad auf NAS
    filename        TEXT NOT NULL,
    file_extension  TEXT,
    file_size       BIGINT,
    file_hash       TEXT,                        -- SHA256 zur Änderungserkennung
    last_modified   TIMESTAMP WITH TIME ZONE,

    -- Von Tika extrahiert
    extracted_text  TEXT,                         -- Volltext (kann groß sein)
    tika_content_type TEXT,                       -- MIME-Type laut Tika
    tika_metadata   JSONB,                       -- Alle Tika-Metadaten als JSON

    -- Von Ollama klassifiziert
    fach            TEXT,                         -- Englisch, Spanisch, Sonstige
    klasse          TEXT,                         -- 5-13
    thema           TEXT,                         -- Kurzbeschreibung
    typ             TEXT,                         -- Arbeitsblatt, Präsentation, Test, Audio...
    niveau          TEXT,                         -- A1, A2, B1, B2, C1, C2
    ollama_raw      JSONB,                       -- Vollständige Ollama-Antwort

    -- Verwaltung
    indexed_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    classification_status TEXT DEFAULT 'pending', -- pending, success, failed, skipped
    error_message   TEXT
);

CREATE INDEX idx_documents_fach ON documents(fach);
CREATE INDEX idx_documents_klasse ON documents(klasse);
CREATE INDEX idx_documents_typ ON documents(typ);
CREATE INDEX idx_documents_niveau ON documents(niveau);
CREATE INDEX idx_documents_status ON documents(classification_status);
```

### 3.5 MeiliSearch (MicroVM edu-search)

| Eigenschaft | Wert |
|---|---|
| **NixOS-Modul** | `services.meilisearch` |
| **Port** | `7700` |
| **Bind** | `0.0.0.0` (erreichbar für Web-UI und API) |
| **Index** | `edu_documents` |
| **Felder** | `id`, `filename`, `filepath`, `content`, `fach`, `klasse`, `thema`, `typ`, `niveau`, `smb_url` |
| **Filterable** | `fach`, `klasse`, `typ`, `niveau` |
| **Sortable** | `klasse`, `filename`, `last_modified` |
| **Persistenz** | `/persist/var/lib/meilisearch` (impermanence) |
| **Backup nötig?** | ⚠️ Kann aus PostgreSQL + NAS-Daten rebuilt werden |

> **Warum MeiliSearch statt Elasticsearch?**
> - MeiliSearch ist bereits teilweise konfiguriert (`meilisearch.nix` existiert)
> - Deutlich leichter (RAM: ~100MB vs. ~2GB für Elasticsearch)
> - Bessere NixOS-Integration (`services.meilisearch` ist ein offizielles Modul)
> - Typo-tolerante Suche out-of-the-box (perfekt für Ina)
> - Faceted Search / Filterbare Attribute = ideal für Dropdowns
> - Kein Docker nötig (im Gegensatz zu Elasticsearch in NixOS)
> - Falls doch Elasticsearch gewünscht: Plan ist modular, Austausch möglich

### 3.6 Python Indexer Service (MicroVM edu-search)

| Eigenschaft | Wert |
|---|---|
| **Betrieb** | `systemd`-Service (`edu-indexer.service`) |
| **Sprache** | Python 3.12 mit Nix-verwalteter Umgebung |
| **Abhängigkeiten** | `watchdog`, `requests` (oder `tika-client`), `psycopg2`, `meilisearch-python` |
| **Funktion** | Datei-Watcher → Tika → Ollama → PostgreSQL → MeiliSearch |
| **Persistenz** | `/persist/var/lib/edu-indexer/state.json` (Indexierungs-Status) |
| **Backup nötig?** | ⚠️ `state.json` optional – Re-Index aus NAS jederzeit möglich |

**Ollama-Prompt für die Klassifikation:**

```text
Du bist ein Klassifikations-Assistent für Unterrichtsmaterialien einer Lehrerin
für Englisch und Spanisch. Analysiere den folgenden Text und extrahiere die Metadaten.

Antworte NUR mit validem JSON, keine Erklärungen:
{
  "fach": "Englisch" oder "Spanisch" oder "Sonstige",
  "klasse": "5" bis "13" oder "unbekannt",
  "thema": "kurze Beschreibung des Themas (max 50 Zeichen)",
  "typ": "Arbeitsblatt" oder "Präsentation" oder "Test" oder "Klausur" oder "Audio" oder "Video" oder "Bild" oder "Sonstiges",
  "niveau": "A1" oder "A2" oder "B1" oder "B2" oder "C1" oder "C2" oder "unbekannt"
}

TEXT:
{extracted_text_first_3000_chars}

DATEINAME: {filename}
```

### 3.7 Web-UI (MicroVM edu-search)

| Eigenschaft | Wert |
|---|---|
| **Framework** | Statische SPA mit InstantSearch.js + MeiliSearch JS Client |
| **Server** | Nginx (als statischer Fileserver) oder Caddy |
| **Port** | `8080` |
| **Features** | Suchfeld (Volltext), Dropdowns (Fach/Klasse/Typ/Niveau), Ergebnisliste |
| **Datei-Öffnung** | Link als `smb://HL-3-RZ-SMB-01/shares/...` (öffnet im Explorer) |
| **Persistenz** | Keine (statische Dateien im Nix-Store) |
| **Backup nötig?** | ❌ Nein (ist Nix-konfiguriert) |

---

## 4. Datei- und Verzeichnisstruktur im Nix-Repo

### Neue und geänderte Dateien

```text
nixos/
├── hosts/HL-1-MRZ-HOST-01/
│   ├── modules/
│   │   └── gpu.nix                          ← NEU: NVIDIA-Treiber + CUDA
│   │   └── ollama.nix                       ← NEU: Ollama Service nativ auf HOST-01
│   │   └── default.nix                      ← ÄNDERN: gpu.nix + ollama.nix importieren
│   ├── guests/
│   │   ├── edu-search.nix                   ← NEU: MicroVM-Definition
│   │   ├── edu-search/
│   │   │   ├── tika.nix                     ← NEU: Apache Tika systemd Service
│   │   │   ├── postgresql.nix               ← NEU: PostgreSQL mit Schema
│   │   │   ├── meilisearch.nix              ← NEU: MeiliSearch Konfiguration
│   │   │   ├── indexer.nix                  ← NEU: Python Indexer systemd Service
│   │   │   ├── indexer.py                   ← NEU: Python Indexer Skript
│   │   │   ├── webui.nix                    ← NEU: Nginx + statische SPA
│   │   │   ├── webui/                       ← NEU: HTML/CSS/JS der Suchoberfläche
│   │   │   │   ├── index.html
│   │   │   │   ├── style.css
│   │   │   │   └── app.js
│   │   │   └── backup.nix                   ← NEU: Restic Backup für PostgreSQL + MeiliSearch
│   │   ├── ai.nix                           ← ÄNDERN: Ollama entfernen, nur Open-WebUI
│   │   └── meilisearch.nix                  ← ENTFERNEN/ERSETZEN: alte unfertige Konfiguration
│   ├── guests.nix                           ← ÄNDERN: edu-search MicroVM hinzufügen
│   └── default.nix                          ← evtl. ÄNDERN: Module-Import
├── globals.nix                              ← ÄNDERN: HL-3-RZ-EDU-01 Host-ID hinzufügen
└── PLAN_EDU_SEARCH.md                       ← DIESE DATEI
```

### Beziehung zur bestehenden Infrastruktur

| Bestehend | Aktion | Begründung |
|---|---|---|
| `guests/ai.nix` | Refactoring | Ollama raus (→ HOST-01 nativ), Open-WebUI bleibt |
| `guests/meilisearch.nix` | Ersetzen | Alte unfertige Config, wird durch edu-search ersetzt |
| `guests/meilisearch/` | Ersetzen | Altes Python-Skript, wird durch neuen Indexer ersetzt |
| `guests/samba.nix` | Unverändert | NAS-Shares bleiben wie sie sind |
| `guests/sync_ina.nix` | Unverändert | Syncthing für Ina bleibt parallel |
| `guests.nix` | Erweitern | Neue MicroVM `edu-search` eintragen |
| `globals.nix` | Erweitern | Host-ID `HL-3-RZ-EDU-01.id = 114` in vlan40 |

---

## 5. Phase 1 – Fundament (1-2 Wochenenden)

### 5.1 NVIDIA-Treiber auf HOST-01

**Datei: `hosts/HL-1-MRZ-HOST-01/modules/gpu.nix`**

```nix
# GPU-Konfiguration für NVIDIA GeForce GTX 1660 SUPER (TU116) auf HOST-01
# PCI: 2d:00.0, Turing-Architektur, 6GB VRAM
# BESTÄTIGT: lspci zeigt "TU116 [GeForce GTX 1660 SUPER] (rev a1)"
{ config, lib, pkgs, ... }: {
  # NVIDIA-Treiber (headless, kein X11/Wayland nötig auf Server)
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    # TU116 (Turing) braucht den proprietären Treiber, NICHT open
    open = false;
    nvidiaSettings = false;  # Kein GUI-Tool auf Server
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
  };

  # Kernel-Module
  boot.initrd.kernelModules = [ "nvidia" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidiaPackages.stable ];

  # CUDA verfügbar machen + GPU-Monitoring
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia   # GPU-Monitoring (wie htop für GPU)
    cudaPackages.cuda_nvcc  # Optional: CUDA Compiler für Tests
  ];

  # nvidia-smi soll funktionieren
  services.xserver.videoDrivers = [ "nvidia" ];
  # Auf headless-Servern: Kein Display-Manager, aber Treiber wird geladen
}
```

### 5.2 Ollama nativ auf HOST-01

**Datei: `hosts/HL-1-MRZ-HOST-01/modules/ollama.nix`**

```nix
# Ollama LLM Service direkt auf HOST-01 (GPU-beschleunigt)
{ config, pkgs, ... }: {
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";  # GPU-Beschleunigung via NVIDIA CUDA
    # loadModels = [ "mistral:7b" ];  # Optional: Modell beim Start laden
  };

  # Firewall: Ollama nur aus vlan40 (Server-VLAN) erreichbar
  networking.firewall.allowedTCPPorts = [ 11434 ];

  # Impermanence: Ollama-Daten (Modelle) persistent machen
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/ollama";
      mode = "0700";
    }
  ];
}
```

**Datei: `hosts/HL-1-MRZ-HOST-01/modules/default.nix` (anpassen):**

```nix
{
  imports = [
    ./profiles.nix
    ./security.nix
    ./services.nix
    ./system.nix
    ./gpu.nix      # NEU
    ./ollama.nix   # NEU
  ];
}
```

### 5.3 MicroVM edu-search registrieren

**Datei: `globals.nix` – neue Host-ID hinzufügen:**

```nix
# Im vlan40-Block hinzufügen:
hosts.HL-3-RZ-EDU-01.id = 114;
```

**Datei: `guests.nix` – neue MicroVM eintragen:**

```nix
# Im Block nach den bestehenden mkMicrovm-Aufrufen:
// mkMicrovm "edu-search" "HL-3-RZ-EDU-01" "enp38s0" "02:08:27:ee:9e:16" "vlan40" {
  enableSharedDataset = true;   # Zugriff auf /shared (Inas Dateien)
  enableStorageDataset = true;  # Zugriff auf /storage (Bibliothek, Dokumente)
}
```

### 5.4 MicroVM edu-search Grundkonfiguration

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search.nix`**

```nix
{
  config,
  globals,
  secretsPath,
  hostName,
  lib,
  pkgs,
  ...
}: let
  eduDomain = "edu.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";
  ollamaHost = globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4;
in {
  microvm.mem = 1024 * 6;  # 6 GB RAM (Tika+PG+Meili+Python) – 64GB Host hat genug
  microvm.vcpu = 4;

  networking.hostName = hostName;

  # NAS-Shares als virtiofs in die MicroVM mounten (read-only)
  microvm.shares = [
    {
      source = "/shared/shares/users/ina";
      mountPoint = "/nas/ina";
      tag = "edu-ina";
      proto = "virtiofs";
    }
    {
      source = "/storage/shares/bibliothek";
      mountPoint = "/nas/bibliothek";
      tag = "edu-bib";
      proto = "virtiofs";
    }
    {
      source = "/storage/shares/dokumente";
      mountPoint = "/nas/dokumente";
      tag = "edu-dok";
      proto = "virtiofs";
    }
  ];

  imports = [
    ./edu-search/tika.nix
    ./edu-search/postgresql.nix
    ./edu-search/meilisearch.nix
    ./edu-search/indexer.nix
    ./edu-search/webui.nix
    ./edu-search/backup.nix
  ];

  # Firewall: Web-UI erreichbar machen
  networking.firewall.allowedTCPPorts = [ 8080 7700 ];

  # Impermanence
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];

  # Reverse Proxy via Caddy auf HOST-02
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${eduDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4}:8080
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  fileSystems = lib.mkMerge [
    { "/state".neededForBoot = true; }
  ];

  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
```

### 5.5 Apache Tika Service

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/tika.nix`**

> **✅ GEKLÄRT:** `pkgs.apacheTika` existiert NICHT in nixpkgs-unstable. Wir verwenden
> `fetchurl` um das offizielle JAR direkt von Apache herunterzuladen.

```nix
# Apache Tika als HTTP-Server für Textextraktion
# HINWEIS: pkgs.apacheTika existiert nicht in nixpkgs, daher fetchurl des JAR
{ pkgs, lib, ... }: let
  tikaPort = 9998;
  tikaVersion = "3.1.0";

  # Tika Server JAR direkt von Apache herunterladen
  # SHA256-Hash muss beim ersten Build via `nix-prefetch-url` ermittelt werden:
  #   nix-prefetch-url https://dlcdn.apache.org/tika/${tikaVersion}/tika-server-standard-${tikaVersion}.jar
  tika-server-jar = pkgs.fetchurl {
    url = "https://dlcdn.apache.org/tika/${tikaVersion}/tika-server-standard-${tikaVersion}.jar";
    # PLATZHALTER – muss vor dem ersten Build ersetzt werden!
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in {
  # Java-Runtime für Tika
  environment.systemPackages = [ pkgs.jdk21_headless ];

  # Tika als systemd Service (kein NixOS-Modul vorhanden, daher manuell)
  systemd.services.tika-server = {
    description = "Apache Tika Server for text extraction";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
      DynamicUser = true;
      StateDirectory = "tika";

      ExecStart = ''
        ${pkgs.jdk21_headless}/bin/java \
          -Xmx512m \
          -jar ${tika-server-jar} \
          --host 127.0.0.1 \
          --port ${toString tikaPort}
      '';

      # Sicherheit: Minimale Rechte
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };

  # HINWEIS: Tika ist stateless, kein Persistenz/Backup nötig
}
```

> **Alternative:** Falls der `fetchurl`-Ansatz Probleme macht (z.B. Hash-Änderungen bei
> Apache-Mirror-Updates), kann stattdessen `python3Packages.tika` (v3.1.0) verwendet werden.
> Dieses Python-Paket managed den Tika-Server-Download und -Start selbst. Der Nachteil:
> Weniger Kontrolle über den Serverprozess und kein separater systemd-Service.

### 5.6 PostgreSQL mit Schema

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/postgresql.nix`**

```nix
# PostgreSQL für Metadaten-Speicherung
{ config, pkgs, lib, ... }: {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings = {
      listen_addresses = "127.0.0.1";
      port = 5432;
      # Leichtgewichtige Einstellungen für MicroVM
      shared_buffers = "128MB";
      work_mem = "8MB";
      max_connections = 20;
    };

    # Datenbank und User automatisch anlegen
    ensureDatabases = [ "edu_search" ];
    ensureUsers = [
      {
        name = "edu_indexer";
        ensureDBOwnership = true;
      }
    ];

    # Schema beim ersten Start anlegen
    initialScript = pkgs.writeText "edu-search-init.sql" ''
      -- Nur ausgeführt wenn DB neu erstellt wird
      \c edu_search;

      CREATE TABLE IF NOT EXISTS documents (
          id              SERIAL PRIMARY KEY,
          filepath        TEXT UNIQUE NOT NULL,
          filename        TEXT NOT NULL,
          file_extension  TEXT,
          file_size       BIGINT,
          file_hash       TEXT,
          last_modified   TIMESTAMP WITH TIME ZONE,

          extracted_text  TEXT,
          tika_content_type TEXT,
          tika_metadata   JSONB,

          fach            TEXT,
          klasse          TEXT,
          thema           TEXT,
          typ             TEXT,
          niveau          TEXT,
          ollama_raw      JSONB,

          indexed_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          classification_status TEXT DEFAULT 'pending',
          error_message   TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_doc_fach ON documents(fach);
      CREATE INDEX IF NOT EXISTS idx_doc_klasse ON documents(klasse);
      CREATE INDEX IF NOT EXISTS idx_doc_typ ON documents(typ);
      CREATE INDEX IF NOT EXISTS idx_doc_niveau ON documents(niveau);
      CREATE INDEX IF NOT EXISTS idx_doc_status ON documents(classification_status);
      CREATE INDEX IF NOT EXISTS idx_doc_hash ON documents(file_hash);

      GRANT ALL PRIVILEGES ON DATABASE edu_search TO edu_indexer;
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO edu_indexer;
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO edu_indexer;
    '';
  };

  # Impermanence: PostgreSQL-Daten persistent
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/postgresql";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
  ];
}
```

---

## 6. Phase 2 – Suche & Indexierung (1 Wochenende)

### 6.1 MeiliSearch Konfiguration

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/meilisearch.nix`**

```nix
# MeiliSearch für Volltext- und Facettensuche
{ config, pkgs, lib, ... }: let
  meiliPort = 7700;
in {
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;
    # WICHTIG: Master-Key via agenix Secret verwalten!
    # Vorerst Platzhalter, in Phase 4 durch Secret ersetzen
    environment = "production";
    listenAddress = "0.0.0.0";
    listenPort = meiliPort;
  };

  # Impermanence: MeiliSearch-Daten persistent
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/meilisearch";
      user = "meilisearch";
      group = "meilisearch";
      mode = "0700";
    }
  ];
}
```

> **MeiliSearch Index-Konfiguration** (wird vom Python-Indexer beim Start gesetzt):
> - `filterableAttributes`: `["fach", "klasse", "typ", "niveau"]`
> - `sortableAttributes`: `["klasse", "filename", "last_modified"]`
> - `searchableAttributes`: `["content", "filename", "thema", "fach"]`
> - `displayedAttributes`: `["id", "filename", "filepath", "fach", "klasse", "thema", "typ", "niveau", "smb_url", "last_modified"]`
>   (Wichtig: `content` wird NICHT in displayedAttributes aufgenommen, um die Antwortgröße klein zu halten)

### 6.2 Python Indexer Service

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/indexer.nix`**

```nix
# Python-basierter Indexer: Watchdog → Tika → Ollama → PostgreSQL → MeiliSearch
{ config, pkgs, lib, globals, ... }: let
  ollamaHost = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";
  tikaUrl = "http://127.0.0.1:9998";
  meiliUrl = "http://127.0.0.1:7700";
  # Alle zu überwachenden NAS-Verzeichnisse
  watchDirs = "/nas/ina/schule,/nas/bibliothek,/nas/dokumente";
  # SMB-Basis-URL für die Web-UI Links
  smbBase = "smb://HL-3-RZ-SMB-01/shares";

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    watchdog          # Dateisystem-Überwachung
    requests          # HTTP-Client für Tika + Ollama
    psycopg2          # PostgreSQL-Client
    meilisearch       # MeiliSearch Python Client (PyPI: meilisearch)
  ]);

  indexerScript = ./indexer.py;
in {
  systemd.services.edu-indexer = {
    description = "Edu-Search Document Indexer (Tika + Ollama + MeiliSearch)";
    after = [
      "network-online.target"
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
    ];
    requires = [
      "postgresql.service"
      "meilisearch.service"
      "tika-server.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "30s";
      User = "edu-indexer";
      Group = "users";

      ExecStart = "${pythonEnv}/bin/python ${indexerScript}";

      Environment = [
        "OLLAMA_URL=${ollamaHost}"
        "TIKA_URL=${tikaUrl}"
        "MEILI_URL=${meiliUrl}"
        "MEILI_INDEX=edu_documents"
        "WATCH_DIRS=${watchDirs}"
        "SMB_BASE=${smbBase}"
        "DB_HOST=127.0.0.1"
        "DB_PORT=5432"
        "DB_NAME=edu_search"
        "DB_USER=edu_indexer"
        "STATE_FILE=/var/lib/edu-indexer/state.json"
        "OLLAMA_MODEL=mistral:7b"
        # Polling-Interval in Sekunden (virtiofs sendet nicht immer inotify)
        "POLL_INTERVAL=60"
      ];

      # Sicherheit
      NoNewPrivileges = true;
      ProtectHome = true;
      PrivateTmp = true;
      ReadOnlyPaths = [ "/nas" ];
      ReadWritePaths = [ "/var/lib/edu-indexer" ];
    };
  };

  # User für den Indexer
  users.users.edu-indexer = {
    isSystemUser = true;
    group = "users";
    home = "/var/lib/edu-indexer";
    createHome = true;
  };

  # Impermanence
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/edu-indexer";
      user = "edu-indexer";
      group = "users";
      mode = "0750";
    }
  ];
}
```

### 6.3 Python Indexer Skript (Kernlogik)

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/indexer.py`**

```python
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
"""
import os
import sys
import json
import time
import hashlib
import logging
import re
from pathlib import Path
from datetime import datetime, timezone

import requests
import psycopg2
import psycopg2.extras
import meilisearch
from watchdog.observers.polling import PollingObserver
from watchdog.events import FileSystemEventHandler

# --- Konfiguration aus Umgebungsvariablen ---
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://10.15.40.10:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mistral:7b")
TIKA_URL = os.getenv("TIKA_URL", "http://127.0.0.1:9998")
MEILI_URL = os.getenv("MEILI_URL", "http://127.0.0.1:7700")
MEILI_KEY = os.getenv("MEILI_KEY", "")
MEILI_INDEX = os.getenv("MEILI_INDEX", "edu_documents")
WATCH_DIRS = os.getenv("WATCH_DIRS", "/nas/ina/schule").split(",")
SMB_BASE = os.getenv("SMB_BASE", "smb://HL-3-RZ-SMB-01/shares")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "edu_search")
DB_USER = os.getenv("DB_USER", "edu_indexer")
STATE_FILE = os.getenv("STATE_FILE", "/var/lib/edu-indexer/state.json")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "60"))

# Unterstützte Dateierweiterungen
SUPPORTED_EXTENSIONS = {
    ".pdf", ".docx", ".doc", ".pptx", ".ppt", ".odt", ".odp", ".ods",
    ".xlsx", ".xls", ".rtf", ".txt", ".html", ".htm", ".epub",
    ".mp3", ".mp4", ".m4a", ".wav",  # Audio/Video: nur Metadaten
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
log = logging.getLogger("edu-indexer")

# --- Hilfsfunktionen ---

def file_hash(filepath: str) -> str:
    """SHA256-Hash einer Datei berechnen."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def extract_text_tika(filepath: str) -> tuple[str, str, dict]:
    """Text via Apache Tika extrahieren. Returns (text, content_type, metadata)."""
    try:
        with open(filepath, "rb") as f:
            # Tika /tika Endpoint: gibt Plaintext zurück
            resp = requests.put(
                f"{TIKA_URL}/tika",
                data=f,
                headers={"Accept": "text/plain"},
                timeout=120,
            )
            resp.raise_for_status()
            text = resp.text.strip()

        # Metadaten separat holen
        with open(filepath, "rb") as f:
            meta_resp = requests.put(
                f"{TIKA_URL}/meta",
                data=f,
                headers={"Accept": "application/json"},
                timeout=60,
            )
            meta_resp.raise_for_status()
            metadata = meta_resp.json()
            content_type = metadata.get("Content-Type", "unknown")

        return text, content_type, metadata
    except Exception as e:
        log.error(f"Tika-Extraktion fehlgeschlagen für {filepath}: {e}")
        return "", "error", {}


def classify_with_ollama(text: str, filename: str) -> dict:
    """
    Text via Ollama LLM klassifizieren.
    Gibt ein Dict mit fach, klasse, thema, typ, niveau zurück.
    """
    # Nur die ersten 3000 Zeichen senden (Token-Limit + Kosten)
    snippet = text[:3000] if text else "(kein Text extrahiert)"

    prompt = f"""Du bist ein Klassifikations-Assistent für Unterrichtsmaterialien einer Lehrerin
für Englisch und Spanisch. Analysiere den folgenden Text und extrahiere die Metadaten.

Antworte NUR mit validem JSON, keine Erklärungen davor oder danach:
{{
  "fach": "Englisch" oder "Spanisch" oder "Sonstige",
  "klasse": "5" bis "13" oder "unbekannt",
  "thema": "kurze Beschreibung des Themas (max 50 Zeichen)",
  "typ": "Arbeitsblatt" oder "Präsentation" oder "Test" oder "Klausur" oder "Audio" oder "Video" oder "Bild" oder "Sonstiges",
  "niveau": "A1" oder "A2" oder "B1" oder "B2" oder "C1" oder "C2" oder "unbekannt"
}}

DATEINAME: {filename}

TEXT:
{snippet}"""

    try:
        resp = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "stream": False,
                "format": "json",
                "options": {"temperature": 0.1, "num_predict": 256},
            },
            timeout=120,
        )
        resp.raise_for_status()
        raw = resp.json().get("response", "")
        # JSON aus der Antwort extrahieren (Ollama gibt manchmal Wrapper-Text)
        match = re.search(r"\{[^{}]+\}", raw, re.DOTALL)
        if match:
            result = json.loads(match.group())
            return {
                "fach": result.get("fach", "unbekannt"),
                "klasse": result.get("klasse", "unbekannt"),
                "thema": result.get("thema", "")[:100],
                "typ": result.get("typ", "Sonstiges"),
                "niveau": result.get("niveau", "unbekannt"),
                "_raw": raw,
            }
        else:
            log.warning(f"Ollama-Antwort enthielt kein JSON: {raw[:200]}")
            return {"fach": "unbekannt", "klasse": "unbekannt", "thema": "",
                    "typ": "Sonstiges", "niveau": "unbekannt", "_raw": raw}
    except Exception as e:
        log.error(f"Ollama-Klassifikation fehlgeschlagen: {e}")
        return {"fach": "error", "klasse": "error", "thema": str(e)[:100],
                "typ": "error", "niveau": "error", "_raw": ""}


def filepath_to_smb_url(filepath: str) -> str:
    """Konvertiert einen lokalen NAS-Pfad in eine smb:// URL."""
    # /nas/ina/schule/Englisch/test.docx -> smb://HL-3-RZ-SMB-01/shares/users/ina/schule/Englisch/test.docx
    path_map = {
        "/nas/ina": f"{SMB_BASE}/users/ina",
        "/nas/bibliothek": f"{SMB_BASE}/bibliothek",
        "/nas/dokumente": f"{SMB_BASE}/dokumente",
    }
    for local_prefix, smb_prefix in path_map.items():
        if filepath.startswith(local_prefix):
            return filepath.replace(local_prefix, smb_prefix, 1)
    return filepath


def get_db_connection():
    """PostgreSQL-Verbindung herstellen."""
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER
    )


def get_meili_client():
    """MeiliSearch-Client erstellen und Index konfigurieren."""
    client = meilisearch.Client(MEILI_URL, MEILI_KEY or None)
    index = client.index(MEILI_INDEX)
    # Index-Einstellungen setzen (idempotent)
    index.update_filterable_attributes(["fach", "klasse", "typ", "niveau"])
    index.update_sortable_attributes(["klasse", "filename", "last_modified"])
    index.update_searchable_attributes(["content", "filename", "thema", "fach"])
    index.update_displayed_attributes([
        "id", "filename", "filepath", "fach", "klasse", "thema",
        "typ", "niveau", "smb_url", "last_modified", "file_extension",
    ])
    return index


# --- Kernlogik: Einzelne Datei verarbeiten ---

def process_file(filepath: str, db_conn, meili_index):
    """Eine einzelne Datei durch die komplette Pipeline schicken."""
    path = Path(filepath)

    # Nur unterstützte Dateien
    if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        return

    # Dateigröße und Hash prüfen
    try:
        stat = path.stat()
        current_hash = file_hash(filepath)
    except OSError as e:
        log.warning(f"Datei nicht lesbar: {filepath}: {e}")
        return

    # Prüfe ob bereits indexiert und unverändert
    with db_conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute("SELECT file_hash FROM documents WHERE filepath = %s", (filepath,))
        row = cur.fetchone()
        if row and row["file_hash"] == current_hash:
            log.debug(f"Unverändert, überspringe: {filepath}")
            return

    log.info(f"Verarbeite: {filepath}")

    # 1. Text extrahieren via Tika
    text, content_type, tika_meta = extract_text_tika(filepath)

    # 2. KI-Klassifikation via Ollama
    if text:
        classification = classify_with_ollama(text, path.name)
        status = "success"
    else:
        classification = {"fach": "unbekannt", "klasse": "unbekannt",
                          "thema": "kein Text extrahiert", "typ": "Sonstiges",
                          "niveau": "unbekannt", "_raw": ""}
        status = "skipped" if path.suffix.lower() in {".mp3", ".mp4", ".m4a", ".wav"} else "failed"

    # 3. In PostgreSQL speichern (UPSERT)
    with db_conn.cursor() as cur:
        cur.execute("""
            INSERT INTO documents (
                filepath, filename, file_extension, file_size, file_hash,
                last_modified, extracted_text, tika_content_type, tika_metadata,
                fach, klasse, thema, typ, niveau, ollama_raw,
                indexed_at, classification_status
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (filepath) DO UPDATE SET
                filename = EXCLUDED.filename,
                file_extension = EXCLUDED.file_extension,
                file_size = EXCLUDED.file_size,
                file_hash = EXCLUDED.file_hash,
                last_modified = EXCLUDED.last_modified,
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
                classification_status = EXCLUDED.classification_status
        """, (
            filepath, path.name, path.suffix.lower(), stat.st_size, current_hash,
            datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc),
            text[:50000] if text else None,  # Limit für DB
            content_type, json.dumps(tika_meta),
            classification.get("fach"), classification.get("klasse"),
            classification.get("thema"), classification.get("typ"),
            classification.get("niveau"), json.dumps(classification.get("_raw", "")),
            datetime.now(timezone.utc), status,
        ))
    db_conn.commit()

    # 4. In MeiliSearch indexieren
    smb_url = filepath_to_smb_url(filepath)
    doc_id = current_hash[:16]  # Kurzer deterministischer ID
    meili_doc = {
        "id": doc_id,
        "filename": path.name,
        "filepath": filepath,
        "file_extension": path.suffix.lower(),
        "smb_url": smb_url,
        "content": text[:10000] if text else "",  # Limit für Suchindex
        "fach": classification.get("fach", "unbekannt"),
        "klasse": classification.get("klasse", "unbekannt"),
        "thema": classification.get("thema", ""),
        "typ": classification.get("typ", "Sonstiges"),
        "niveau": classification.get("niveau", "unbekannt"),
        "last_modified": int(stat.st_mtime),
    }
    try:
        meili_index.add_documents([meili_doc])
        log.info(f"Indexiert: {path.name} -> {classification.get('fach')}/{classification.get('thema')}")
    except Exception as e:
        log.error(f"MeiliSearch-Fehler für {filepath}: {e}")


def delete_from_index(filepath: str, db_conn, meili_index):
    """Eine gelöschte Datei aus PostgreSQL und MeiliSearch entfernen."""
    with db_conn.cursor() as cur:
        cur.execute("SELECT file_hash FROM documents WHERE filepath = %s", (filepath,))
        row = cur.fetchone()
        if row:
            doc_id = row[0][:16]
            try:
                meili_index.delete_document(doc_id)
            except Exception:
                pass
        cur.execute("DELETE FROM documents WHERE filepath = %s", (filepath,))
    db_conn.commit()
    log.info(f"Gelöscht aus Index: {filepath}")


# --- Dateisystem-Watcher ---

class EduFileHandler(FileSystemEventHandler):
    def __init__(self, db_conn, meili_index):
        self.db_conn = db_conn
        self.meili_index = meili_index

    def on_created(self, event):
        if not event.is_directory:
            process_file(event.src_path, self.db_conn, self.meili_index)

    def on_modified(self, event):
        if not event.is_directory:
            process_file(event.src_path, self.db_conn, self.meili_index)

    def on_deleted(self, event):
        if not event.is_directory:
            delete_from_index(event.src_path, self.db_conn, self.meili_index)

    def on_moved(self, event):
        if not event.is_directory:
            delete_from_index(event.src_path, self.db_conn, self.meili_index)
            process_file(event.dest_path, self.db_conn, self.meili_index)


# --- Initiale Indizierung ---

def initial_indexing(db_conn, meili_index):
    """Alle Dateien in den Watch-Verzeichnissen einmalig indizieren."""
    log.info("Starte initiale Indizierung...")
    count = 0
    for watch_dir in WATCH_DIRS:
        watch_path = Path(watch_dir.strip())
        if not watch_path.exists():
            log.warning(f"Verzeichnis existiert nicht: {watch_dir}")
            continue
        for fpath in watch_path.rglob("*"):
            if fpath.is_file() and fpath.suffix.lower() in SUPPORTED_EXTENSIONS:
                try:
                    process_file(str(fpath), db_conn, meili_index)
                    count += 1
                except Exception as e:
                    log.error(f"Fehler bei {fpath}: {e}")
    log.info(f"Initiale Indizierung abgeschlossen: {count} Dateien verarbeitet.")


# --- Hauptprogramm ---

if __name__ == "__main__":
    log.info("=== Edu-Search Indexer gestartet ===")
    log.info(f"Watch-Dirs: {WATCH_DIRS}")
    log.info(f"Ollama: {OLLAMA_URL} (Modell: {OLLAMA_MODEL})")
    log.info(f"Tika: {TIKA_URL}")
    log.info(f"MeiliSearch: {MEILI_URL}")
    log.info(f"PostgreSQL: {DB_HOST}:{DB_PORT}/{DB_NAME}")

    # Verbindungen aufbauen
    db_conn = get_db_connection()
    meili_index = get_meili_client()

    # Initiale Indizierung
    initial_indexing(db_conn, meili_index)

    # Dateisystem-Watcher starten (PollingObserver wegen virtiofs)
    handler = EduFileHandler(db_conn, meili_index)
    observer = PollingObserver(timeout=POLL_INTERVAL)
    for watch_dir in WATCH_DIRS:
        d = watch_dir.strip()
        if os.path.exists(d):
            observer.schedule(handler, d, recursive=True)
            log.info(f"Überwache: {d}")

    observer.start()
    log.info(f"Dateisystem-Watcher aktiv (Polling alle {POLL_INTERVAL}s)")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        log.info("Shutdown angefordert...")
    observer.join()
    db_conn.close()
    log.info("=== Edu-Search Indexer beendet ===")
```

> **HINWEIS zum Indexer-Skript:** Dies ist ein funktionsfähiger Entwurf. Vor dem
> produktiven Einsatz sollten folgende Punkte ergänzt werden:
> - Retry-Logik bei Ollama-Timeouts (GPU kann unter Last stehen)
> - Rate-Limiting für Ollama-Anfragen (max. 1 Request gleichzeitig)
> - Graceful Shutdown mit Signal-Handling
> - Metriken-Export (z.B. Anzahl indexierter Dateien, Fehlerrate)
> - Health-Check Endpoint für Monitoring

---

## 7. Phase 3 – Web-UI für Ina (1 Wochenende)

### 7.1 Nginx als statischer Server

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/webui.nix`**

```nix
# Statische Web-UI für die Unterrichtsmaterial-Suche
{ config, pkgs, lib, globals, ... }: let
  meiliPort = 7700;
  meiliHost = "127.0.0.1";
  webPort = 8080;

  # Statische Web-UI Dateien als Nix-Derivation
  eduWebUI = pkgs.runCommand "edu-search-webui" {} ''
    mkdir -p $out
    cp ${./webui/index.html} $out/index.html
    cp ${./webui/style.css} $out/style.css
    cp ${./webui/app.js} $out/app.js
  '';
in {
  services.nginx = {
    enable = true;

    virtualHosts."edu-search" = {
      listen = [{ addr = "0.0.0.0"; port = webPort; }];
      root = "${eduWebUI}";

      locations."/" = {
        index = "index.html";
        tryFiles = "$uri $uri/ /index.html";
      };

      # MeiliSearch als API-Proxy (damit die SPA direkt suchen kann)
      locations."/meili/" = {
        proxyPass = "http://${meiliHost}:${toString meiliPort}/";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          # CORS für lokale Entwicklung
          add_header Access-Control-Allow-Origin *;
          add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
          add_header Access-Control-Allow-Headers "Content-Type, Authorization";
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ webPort ];
}
```

### 7.2 HTML-Suchoberfläche

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/webui/index.html`**

```html
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Unterrichtsmaterial-Suche</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <h1>📚 Unterrichtsmaterial-Suche</h1>
  </header>

  <main>
    <div class="search-bar">
      <input type="text" id="search-input" placeholder="Suche nach Thema, Inhalt, Dateiname..."
             autofocus autocomplete="off">
    </div>

    <div class="filters">
      <select id="filter-fach">
        <option value="">Alle Fächer</option>
        <option value="Englisch">Englisch</option>
        <option value="Spanisch">Spanisch</option>
        <option value="Sonstige">Sonstige</option>
      </select>

      <select id="filter-klasse">
        <option value="">Alle Klassen</option>
        <option value="5">Klasse 5</option>
        <option value="6">Klasse 6</option>
        <option value="7">Klasse 7</option>
        <option value="8">Klasse 8</option>
        <option value="9">Klasse 9</option>
        <option value="10">Klasse 10</option>
        <option value="11">Klasse 11</option>
        <option value="12">Klasse 12</option>
        <option value="13">Klasse 13</option>
      </select>

      <select id="filter-typ">
        <option value="">Alle Typen</option>
        <option value="Arbeitsblatt">Arbeitsblatt</option>
        <option value="Präsentation">Präsentation</option>
        <option value="Test">Test</option>
        <option value="Klausur">Klausur</option>
        <option value="Audio">Audio</option>
        <option value="Video">Video</option>
        <option value="Sonstiges">Sonstiges</option>
      </select>

      <select id="filter-niveau">
        <option value="">Alle Niveaus</option>
        <option value="A1">A1</option>
        <option value="A2">A2</option>
        <option value="B1">B1</option>
        <option value="B2">B2</option>
        <option value="C1">C1</option>
        <option value="C2">C2</option>
      </select>
    </div>

    <div id="stats" class="stats"></div>

    <div id="results" class="results">
      <p class="placeholder">Gib einen Suchbegriff ein oder wähle einen Filter...</p>
    </div>
  </main>

  <script src="app.js"></script>
</body>
</html>
```

### 7.3 CSS-Styling

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/webui/style.css`**

```css
/* Edu-Search – Einfaches, übersichtliches Design */
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, sans-serif;
  background: #f5f7fa;
  color: #333;
  max-width: 960px;
  margin: 0 auto;
  padding: 20px;
}

header {
  text-align: center;
  margin-bottom: 24px;
}

header h1 {
  font-size: 1.8em;
  color: #2c3e50;
}

.search-bar {
  margin-bottom: 16px;
}

.search-bar input {
  width: 100%;
  padding: 14px 20px;
  font-size: 1.1em;
  border: 2px solid #ddd;
  border-radius: 8px;
  outline: none;
  transition: border-color 0.2s;
}

.search-bar input:focus {
  border-color: #3498db;
}

.filters {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}

.filters select {
  flex: 1;
  min-width: 140px;
  padding: 10px 12px;
  font-size: 0.95em;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: white;
  cursor: pointer;
}

.stats {
  font-size: 0.85em;
  color: #888;
  margin-bottom: 12px;
}

.results {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.result-card {
  background: white;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  padding: 16px;
  cursor: pointer;
  transition: box-shadow 0.2s, border-color 0.2s;
  text-decoration: none;
  color: inherit;
  display: block;
}

.result-card:hover {
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  border-color: #3498db;
}

.result-card .filename {
  font-weight: 600;
  font-size: 1.05em;
  color: #2c3e50;
  margin-bottom: 6px;
}

.result-card .meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 0.85em;
  color: #666;
}

.result-card .meta .tag {
  background: #ecf0f1;
  padding: 2px 8px;
  border-radius: 4px;
}

.result-card .meta .tag.fach-englisch { background: #d5f5e3; color: #1e8449; }
.result-card .meta .tag.fach-spanisch { background: #fdebd0; color: #b9770e; }
.result-card .thema {
  font-size: 0.9em;
  color: #555;
  margin-top: 4px;
}

.placeholder {
  text-align: center;
  color: #aaa;
  padding: 40px;
  font-size: 1.1em;
}
```

### 7.4 JavaScript-Suchlogik

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/webui/app.js`**

```javascript
// Edu-Search Frontend – verbindet sich mit MeiliSearch via /meili/ Proxy
const MEILI_URL = "/meili";
const INDEX_NAME = "edu_documents";

const searchInput = document.getElementById("search-input");
const filterFach = document.getElementById("filter-fach");
const filterKlasse = document.getElementById("filter-klasse");
const filterTyp = document.getElementById("filter-typ");
const filterNiveau = document.getElementById("filter-niveau");
const resultsDiv = document.getElementById("results");
const statsDiv = document.getElementById("stats");

let debounceTimer = null;

// Suche ausführen
async function doSearch() {
  const query = searchInput.value.trim();
  const filters = [];

  if (filterFach.value) filters.push(`fach = "${filterFach.value}"`);
  if (filterKlasse.value) filters.push(`klasse = "${filterKlasse.value}"`);
  if (filterTyp.value) filters.push(`typ = "${filterTyp.value}"`);
  if (filterNiveau.value) filters.push(`niveau = "${filterNiveau.value}"`);

  // Mindestens Query oder Filter nötig
  if (!query && filters.length === 0) {
    resultsDiv.innerHTML = '<p class="placeholder">Gib einen Suchbegriff ein oder wähle einen Filter...</p>';
    statsDiv.textContent = "";
    return;
  }

  try {
    const body = {
      q: query || "",
      filter: filters.length > 0 ? filters.join(" AND ") : undefined,
      limit: 50,
      attributesToHighlight: ["filename", "thema"],
      highlightPreTag: "<mark>",
      highlightPostTag: "</mark>",
    };

    const resp = await fetch(`${MEILI_URL}/indexes/${INDEX_NAME}/search`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = await resp.json();
    renderResults(data);
  } catch (err) {
    resultsDiv.innerHTML = `<p class="placeholder">Fehler bei der Suche: ${err.message}</p>`;
    statsDiv.textContent = "";
  }
}

// Ergebnisse rendern
function renderResults(data) {
  const hits = data.hits || [];
  statsDiv.textContent = `${data.estimatedTotalHits || hits.length} Ergebnis(se) in ${data.processingTimeMs}ms`;

  if (hits.length === 0) {
    resultsDiv.innerHTML = '<p class="placeholder">Keine Ergebnisse gefunden.</p>';
    return;
  }

  resultsDiv.innerHTML = hits.map(hit => {
    const hl = hit._formatted || hit;
    const fachClass = (hit.fach || "").toLowerCase().includes("englisch") ? "fach-englisch"
                    : (hit.fach || "").toLowerCase().includes("spanisch") ? "fach-spanisch" : "";
    return `
      <a class="result-card" href="${hit.smb_url || '#'}" title="Klicke um die Datei zu öffnen">
        <div class="filename">${hl.filename || hit.filename}</div>
        <div class="meta">
          ${hit.fach ? `<span class="tag ${fachClass}">${hit.fach}</span>` : ""}
          ${hit.klasse && hit.klasse !== "unbekannt" ? `<span class="tag">Klasse ${hit.klasse}</span>` : ""}
          ${hit.typ && hit.typ !== "Sonstiges" ? `<span class="tag">${hit.typ}</span>` : ""}
          ${hit.niveau && hit.niveau !== "unbekannt" ? `<span class="tag">${hit.niveau}</span>` : ""}
          ${hit.file_extension ? `<span class="tag">${hit.file_extension}</span>` : ""}
        </div>
        ${hit.thema ? `<div class="thema">${hl.thema || hit.thema}</div>` : ""}
      </a>
    `;
  }).join("");
}

// Event-Listener mit Debounce
function onInputChange() {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(doSearch, 250);
}

searchInput.addEventListener("input", onInputChange);
filterFach.addEventListener("change", doSearch);
filterKlasse.addEventListener("change", doSearch);
filterTyp.addEventListener("change", doSearch);
filterNiveau.addEventListener("change", doSearch);

// Beim Laden: leere Suche zeigen (alle Dokumente)
// doSearch();
```

> **Hinweis zu `smb://` Links:** Windows öffnet `smb://`-Links aus dem Browser normalerweise
> nicht direkt. Alternativen:
> - Link als `file:///\\HL-3-RZ-SMB-01\shares\...` formatieren (Windows UNC-Pfad)
> - Kleines Browser-Plugin oder ein `smb://`-Handler registrieren
> - "Pfad kopieren"-Button statt direktem Link, Ina fügt ihn im Explorer ein
> - Am einfachsten: `\\HL-3-RZ-SMB-01\shares\...` als kopierbaren Text anzeigen

---

## 8. Phase 4 – Backup & Monitoring

### 8.1 Backup-Strategie Übersicht

| Komponente | Wo | Backup nötig? | Methode |
|---|---|---|---|
| **NVIDIA-Treiber** | HOST-01 | ❌ | Im Nix-Store, deklarativ |
| **Ollama Modelle** | HOST-01 `/var/lib/private/ollama` | ⚠️ Optional | Können via `ollama pull` wiederhergestellt werden |
| **PostgreSQL** | MicroVM `/persist/var/lib/postgresql` | ✅ **Ja** | `pg_dump` → Restic → OneDrive/rclone |
| **MeiliSearch** | MicroVM `/persist/var/lib/meilisearch` | ⚠️ Optional | Kann aus PostgreSQL + NAS rebuilt werden |
| **Indexer State** | MicroVM `/persist/var/lib/edu-indexer` | ⚠️ Optional | `state.json` – Re-Index jederzeit möglich |
| **Python-Skript** | Nix-Repo (Git) | ✅ | Git-Versionierung |
| **Web-UI** | Nix-Repo (Git) | ✅ | Git-Versionierung |
| **NAS-Dateien** | Samba MicroVM | ✅ | Bereits durch bestehende Restic-Backups abgedeckt |
| **Nix-Konfiguration** | Git-Repo | ✅ | Git + Forgejo |

### 8.2 Restic-Backup für edu-search

**Datei: `hosts/HL-1-MRZ-HOST-01/guests/edu-search/backup.nix`**

```nix
# Restic-Backup für Edu-Search Metadaten (PostgreSQL)
{ config, pkgs, lib, globals, secretsPath, ... }: {

  # --- Secrets ---
  age.secrets."rclone.conf" = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/samba/rclone.conf.age";
    mode = "440";
  };
  age.secrets.restic-edu-search = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/edu-search/restic-password.age";
    mode = "440";
  };
  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };
  age.secrets.edu-search-hc-ping = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/edu-search/healthchecks-ping.age";
    mode = "440";
  };

  # --- PostgreSQL Dump vor Backup ---
  systemd.services.edu-search-pg-dump = {
    description = "Dump Edu-Search PostgreSQL database before backup";
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      ExecStart = ''
        ${pkgs.postgresql_16}/bin/pg_dump \
          --format=custom \
          --file=/var/lib/edu-search-backup/edu_search.pgdump \
          edu_search
      '';
    };
  };

  systemd.tmpfiles.settings."10-edu-backup" = {
    "/var/lib/edu-search-backup".d = {
      user = "postgres";
      group = "postgres";
      mode = "0750";
    };
  };

  # --- Restic Backup ---
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";

    script-post = ''
      pingKey="$(cat ${config.age.secrets.edu-search-hc-ping.path})";
      if [ $EXIT_STATUS -ne 0 ]; then
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
          -H 'Title: Backup (edu-search) failed!' \
          -H 'Tags: backup,restic,edu-search' \
          -d "Restic edu-search backup error!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused \
          "https://health.czichy.com/ping/$pingKey/backup-edu-search/fail"
      else
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused \
          "https://health.czichy.com/ping/$pingKey/backup-edu-search"
      fi
    '';
  in {
    edu-search-backup = {
      initialize = true;
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-edu-search";

      paths = [
        "/var/lib/edu-search-backup"          # PostgreSQL Dump
        "/var/lib/edu-indexer/state.json"      # Indexer-Status (optional)
      ];

      exclude = [];
      passwordFile = config.age.secrets.restic-edu-search.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;
      backupCleanupCommand = script-post;

      # pg_dump muss vorher laufen
      backupPrepareCommand = ''
        systemctl start edu-search-pg-dump.service
      '';

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 2"
      ];

      timerConfig = {
        OnCalendar = "*-*-* 02:00:00";  # Nachts um 2 Uhr
      };
    };
  };

  # Backup-Verzeichnis persistent
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/edu-search-backup";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
  ];
  # Needed so we don't run out of tmpfs space
  environment.persistence."/state".directories = [
    {
      directory = "/var/cache/edu-search";
      user = "root";
      group = "root";
      mode = "0750";
    }
  ];
}
```

### 8.3 Rebuild-Strategie (Disaster Recovery)

Falls die MicroVM oder Daten verloren gehen:

1. **Nix-Konfiguration** → `nixos-rebuild` erstellt die MicroVM neu
2. **PostgreSQL** → Restic-Restore des `pg_dump` → `pg_restore`
3. **MeiliSearch** → Muss NICHT restored werden! Der Indexer kann MeiliSearch komplett
   aus PostgreSQL-Daten neu befüllen (ein Re-Index-Skript sollte als Management-Command
   bereitgestellt werden)
4. **Ollama-Modelle** → `ollama pull mistral:7b` (5 Minuten Download)
5. **NAS-Dateien** → Bereits durch Samba-Restic-Backups geschützt

### 8.4 Monitoring

```nix
# In edu-search.nix ergänzen:
globals.monitoring.http.edu-search = {
  url = "http://${globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4}:8080";
  expectedBodyRegex = "Unterrichtsmaterial";
  network = "vlan40";
};

globals.monitoring.tcp.edu-search-meili = {
  host = globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4;
  port = 7700;
  network = "vlan40";
};
```

---

## 9. Netzwerk & Globals

### 9.1 Änderungen in `globals.nix`

```nix
# In vlan40.hosts hinzufügen:
hosts.HL-3-RZ-EDU-01.id = 114;    # Edu-Search MicroVM
```

### 9.2 Änderungen in `guests.nix`

```nix
# Neue MicroVM registrieren (nach den bestehenden mkMicrovm-Aufrufen):
// mkMicrovm "edu-search" "HL-3-RZ-EDU-01" "enp38s0" "02:08:27:ee:9e:16" "vlan40" {
  enableSharedDataset = true;    # /shared → Inas Syncthing-Dateien
  enableStorageDataset = true;   # /storage → Bibliothek, Dokumente
}
```

### 9.3 Neue systemd.tmpfiles für HOST-01

```nix
# In guests.nix, im systemd.tmpfiles.settings-Block:
"10-edu-search-shares" = {
  "/storage/shares/bibliothek".d = {
    user = "root";
    group = "root";
    mode = "0777";
  };
};
```

### 9.4 Netzwerkdiagramm

```text
vlan40 (10.15.40.0/24)
├── .10   HL-1-MRZ-HOST-01      (Ollama :11434)
├── .11   HL-3-RZ-SMB-01        (Samba – NAS-Dateien)
├── .13   HL-3-RZ-SYNC-01       (Syncthing Christian)
├── .113  HL-3-RZ-SYNC-02       (Syncthing Ina)
├── .114  HL-3-RZ-EDU-01  ← NEU (Edu-Search: Tika+PG+Meili+WebUI)
├── .99   HL-3-MRZ-FW-01        (Gateway/Firewall)
└── ...   (weitere bestehende VMs)

Datenflüsse:
  EDU-01 ──HTTP:11434──→ HOST-01 (Ollama API)
  EDU-01 ──virtiofs────→ HOST-01 ZFS Storage (NAS-Shares, read-only)
  EDU-01 ──HTTP:8080───→ HOST-02 Caddy → Internet (edu.czichy.com)
  Inas PC ──SMB:445────→ SMB-01 (NAS lesen/schreiben)
  Inas PC ──HTTPS──────→ edu.czichy.com (Suche)
```

---

## 10. Offene Fragen & Risiken

### Offene Fragen (vor Implementierung klären)

| # | Frage | Status | Auswirkung |
|---|---|---|---|
| 1 | **Welche NVIDIA-GPU ist in HOST-01?** | ✅ **GTX 1660 SUPER** (TU116, 6GB VRAM, PCI `2d:00.0`) | `nvidiaPackages.stable`, `open = false`, max 7B-8B Modelle |
| 2 | **Wie viel RAM hat HOST-01?** | ✅ **64GB** (34GB frei) | Mehr als genug für alles – edu-search MicroVM kann 6GB bekommen |
| 3 | **Ist `pkgs.apacheTika` in nixpkgs verfügbar?** | ✅ **Nein** – `fetchurl` des JAR nutzen | `python3Packages.tika` (3.1.0) und `tika-client` (0.10.0) existieren als Python-Bindings. Tika-Server-JAR via `fetchurl` beziehen, mit `jdk21_headless` ausführen |
| 4 | **MeiliSearch Master-Key:** Soll er via agenix verwaltet werden? | ❓ Offen | Aktuell Platzhalter – für Produktion Secret nötig |
| 5 | **Sollen ALLE Ina-Ordner indexiert werden?** Oder nur `/schule/`? | ❓ Offen | Bestimmt Umfang und Dauer der initialen Indexierung |
| 6 | **smb:// Links im Browser:** Funktioniert das unter Windows? | ❓ Offen | Evtl. UNC-Pfad (`\\server\share\...`) stattdessen oder Kopier-Button |
| 7 | **MAC-Adresse für edu-search MicroVM:** Ist `02:08:27:ee:9e:16` frei? | ❓ Offen | Muss gegen bestehende MACs in `guests.nix` geprüft werden |
| 8 | **Bestehende `meilisearch.nix` und `ai.nix`:** Entfernen oder behalten? | ❓ Offen | ai.nix refactoren (Ollama raus), meilisearch.nix durch edu-search ersetzen |
| 9 | **restic Secrets:** Existiert bereits ein Secret-Pfad für edu-search? | ❓ Offen | Neue agenix-Secrets müssen generiert und eingecheckt werden |
| 10 | **Domain `edu.czichy.com`:** DNS-Record bei Cloudflare anlegen? | ❓ Offen | Muss vor HTTPS-Zugriff konfiguriert sein |

### Risiken

| Risiko | Wahrscheinlichkeit | Gegenmaßnahme |
|---|---|---|
| **Ollama auf CPU statt GPU** (falscher Treiber) | Niedrig (HW bestätigt) | GPU-Test VOR restlicher Implementierung: `nvidia-smi` + `ollama run mistral:7b "test"` |
| **Tika-JAR nicht in nixpkgs** | Mittel | Fallback: `fetchurl` des offiziellen JAR von Apache Mirror |
| **virtiofs sendet kein inotify** | Hoch | Bereits berücksichtigt: `PollingObserver` statt inotify-basiertem Watcher |
| **Ollama-Klassifikation ungenau** | Mittel | Prompt iterativ verbessern, ggf. Few-Shot-Beispiele hinzufügen |
| **RAM-Engpass auf HOST-01** | ✅ Kein Risiko (64GB) | edu-search MicroVM mit 6GB, 34GB frei nach aktuellen VMs |
| **Ina findet UI nicht intuitiv** | Niedrig | Frühzeitig Feedback einholen, UI ist simpel gehalten |
| **Große initiale Indexierung** (1000+ Dateien) | Mittel | Rate-Limiting einbauen, ggf. über Nacht laufen lassen |

### Priorisierter Aktionsplan

```text
SOFORT (vor Code):
  ✅ lspci | grep -i nvidia  →  GTX 1660 SUPER (TU116, 6GB VRAM)
  ✅ free -h                 →  64GB RAM, 34GB frei
  ✅ nix search tika         →  pkgs.apacheTika existiert NICHT; python3Packages.tika (3.1.0) + tika-client (0.10.0) vorhanden; JAR via fetchurl beziehen
  ✅ MAC-Adresse             →  02:08:27:ee:9e:16 ist frei (Muster 02:XX:27:ee:9e:16, XX=01-07 belegt)

PHASE 1 – Fundament (Wochenende 1):
  □ modules/gpu.nix erstellen (NVIDIA-Treiber)
  □ modules/ollama.nix erstellen (Ollama nativ auf HOST-01)
  □ modules/default.nix anpassen (Imports)
  □ nixos-rebuild, nvidia-smi testen
  □ ollama pull mistral:7b, Testprompt ausführen
  □ globals.nix: HL-3-RZ-EDU-01.id = 114 eintragen
  □ guests.nix: mkMicrovm "edu-search" eintragen
  □ guests/edu-search.nix Grundkonfiguration erstellen
  □ edu-search/tika.nix erstellen
  □ edu-search/postgresql.nix erstellen
  □ MicroVM starten, Tika + PostgreSQL testen

PHASE 2 – Suche & Indexierung (Wochenende 2):
  □ edu-search/meilisearch.nix erstellen
  □ edu-search/indexer.py fertigstellen & testen
  □ edu-search/indexer.nix erstellen (systemd Service)
  □ Testlauf: 10 Dateien manuell indexieren
  □ MeiliSearch-API mit curl testen (Suche + Filter)
  □ Ollama-Prompt mit echten Unterrichtsmaterialien iterieren
  □ Initiale Indexierung aller NAS-Dateien über Nacht laufen lassen

PHASE 3 – Web-UI (Wochenende 3):
  □ edu-search/webui/ HTML+CSS+JS erstellen
  □ edu-search/webui.nix Nginx-Konfiguration
  □ Caddy Reverse Proxy auf HOST-02 konfigurieren
  □ DNS-Record edu.czichy.com anlegen
  □ Ina testen lassen, Feedback einarbeiten
  □ smb://-Links vs. UNC-Pfade auf Windows testen

PHASE 4 – Backup & Härten (parallel):
  □ agenix-Secrets generieren (restic-password, meili-key, hc-ping)
  □ edu-search/backup.nix erstellen
  □ Restic-Backup manuell testen (init + backup + restore)
  □ Monitoring-Einträge in globals hinzufügen
  □ MeiliSearch Master-Key von Platzhalter auf agenix umstellen
  □ ai.nix refactoren (Ollama entfernen, Open-WebUI → HOST-01:11434)
  □ Alte meilisearch.nix + meilisearch/ Ordner aufräumen/entfernen

OPTIONAL / LATER:
  □ Re-Index-Management-Command (PostgreSQL → MeiliSearch rebuild)
  □ Metriken-Export (Prometheus) für den Indexer
  □ Health-Check-Endpoint im Indexer
  □ Few-Shot-Beispiele im Ollama-Prompt für bessere Klassifikation
  □ Vorschau-Thumbnails in der Web-UI (PDF erste Seite etc.)
  □ Automatische Sprach-Erkennung (Englisch/Spanisch/Deutsch) als Fallback
```

---

## Zusammenfassung

| Phase | Aufwand | Ergebnis |
|---|---|---|
| **Phase 1** | 1-2 Wochenenden | GPU + Ollama + Tika + PostgreSQL laufen |
| **Phase 2** | 1 Wochenende | Alle Dateien indexiert, MeiliSearch durchsuchbar |
| **Phase 3** | 1 Wochenende | Ina kann im Browser suchen und Dateien öffnen |
| **Phase 4** | Parallel | Backup gesichert, Monitoring aktiv |

**Gesamtaufwand:** ~3-4 Wochenenden

**Kernprinzip:** Die Originaldateien auf dem NAS werden **niemals verändert**. Das System
liest nur, extrahiert, klassifiziert und indexiert. Ina arbeitet weiterhin ganz normal mit
ihren Dateien über Windows/Samba. Die Websuche ist ein reiner Lesezugriff darauf.