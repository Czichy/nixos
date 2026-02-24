# 🔄 n8n Workflow-Sammlung

## n8n Community Edition v2.6.3 – Import-Anleitung & Credential-Setup

> **Referenz:** Siehe `PLAN_N8N_INTEGRATION.md` im Repo-Root für die vollständige Analyse.
>
> **n8n-Version:** Community Edition **2.6.3** (self-hosted auf HL-3-RZ-N8N-01)
> **URL:** `https://n8n.czichy.com`

---

## Übersicht der Workflows

### Phase 1: Quick Wins (nach Ollama-Setup)

| Datei | Workflow | Trigger | Ziel-Services |
|---|---|---|---|
| `phase1-weekly-summary.json` | Wöchentliche KI-Zusammenfassung | Cron (Sonntag 21:00) | Ollama, Grafana, VictoriaMetrics, ntfy |
| `phase1-ibkr-report.json` | IBKR Tages-Report mit KI-Analyse | Cron (täglich 22:30) | Ollama, Claude (Fallback), IBKR Flex API, ntfy |
| `phase1-paperless-autotag.json` | Paperless KI-Auto-Tagging | Webhook (Paperless) | Ollama, Paperless API, ntfy |

### Phase 2: Edu-Search-Ergänzungen (nach Edu-Search Go-Live)

| Datei | Workflow | Trigger | Ziel-Services |
|---|---|---|---|
| `phase2-edu-new-materials.json` | Tägliche Benachrichtigung neue Materialien | Cron (täglich 18:00) | PostgreSQL (edu-search), ntfy |
| `phase2-edu-weekly-report.json` | Wöchentlicher Edu-Search Status-Report | Cron (Sonntag 20:00) | PostgreSQL (edu-search), ntfy |
| `phase2-edu-error-escalation.json` | Fehler-Eskalation bei Pipeline-Problemen | Cron (alle 6h) | PostgreSQL (edu-search), ntfy |
| `phase2-edu-quiz-generator.json` | KI-generierte Quizfragen für Ina | Webhook (manuell) | PostgreSQL (edu-search), Ollama, E-Mail/ntfy |

---

## Credentials anlegen (n8n Community v2.6.3)

In n8n Community v2.6.3 werden Credentials über die Web-UI verwaltet.
Alle Credentials müssen **vor dem Workflow-Import** angelegt werden,
damit sie beim Import zugewiesen werden können.

> **Umgebungsvariablen:** In n8n v2.6.3 können Credential-Felder auf
> Umgebungsvariablen des n8n-Prozesses zugreifen. Syntax: `={{ $env.VARIABLE_NAME }}`
> (Expression-Modus im Credential-Feld aktivieren via `=`-Button rechts am Feld).
>
> Folgende Env-Vars stehen dem n8n-Prozess auf HL-3-RZ-N8N-01 zur Verfügung:
>
> | Variable | Wert | Quelle |
> |---|---|---|
> | `ANTHROPIC_API_KEY` | Anthropic Claude API-Key | `/run/n8n/env` (via `n8n-setup-env.service`) |
> | `OLLAMA_BASE_URL` | `http://10.15.40.10:11434` | `n8n.nix` `services.n8n.environment` |
> | `EDU_SEARCH_DB_HOST` | `10.15.40.114` | `n8n.nix` `services.n8n.environment` |
> | `EDU_SEARCH_DB_PORT` | `5432` | `n8n.nix` `services.n8n.environment` |
> | `EDU_SEARCH_DB_NAME` | `edu_search` | `n8n.nix` `services.n8n.environment` |
> | `EDU_SEARCH_DB_USER` | `n8n_reader` | `n8n.nix` `services.n8n.environment` |

---

### 1. Ollama (Lokal, GPU-beschleunigt auf HOST-01)

Ollama läuft nativ auf HOST-01 mit CUDA (GTX 1660 SUPER, 6GB VRAM).
n8n v2.6.3 hat einen eingebauten Credential-Typ für Ollama.

**Schritt-für-Schritt:**

1. Öffne `https://n8n.czichy.com`
2. Klicke links in der Sidebar auf **Credentials** (Schlüssel-Symbol)
3. Klicke oben rechts auf **+ Add Credential**
4. Suche im Suchfeld nach **`Ollama`**
5. Wähle den Typ **Ollama API**
6. Fülle die Felder aus:

| Feld | Wert | Hinweis |
|---|---|---|
| **Credential Name** | `Ollama HOST-01` | Frei wählbar, wird in Workflows referenziert |
| **Base URL** | `http://10.15.40.10:11434` | Oder als Expression: `={{ $env.OLLAMA_BASE_URL }}` |

7. Klicke auf **Test Connection** → Muss "Connection tested successfully" zeigen
8. Klicke auf **Save**

> **Kein API-Key nötig.** Ollama hat keine eingebaute Authentifizierung.
> Der Zugriff ist über die Firewall auf vlan40 beschränkt.
>
> **Verfügbare Modelle:** Nach dem ersten Deploy zieht der Service
> `ollama-pull-models` automatisch `mistral:7b`. Weitere Modelle können
> via SSH auf HOST-01 manuell nachgeladen werden:
> ```
> ssh root@10.15.100.10 -- curl -X POST http://127.0.0.1:11434/api/pull \
>   -H 'Content-Type: application/json' \
>   -d '{"name": "llama3.1:8b", "stream": false}'
> ```

---

### 2. Anthropic Claude (Cloud, Fallback für komplexe Aufgaben)

Der Anthropic API-Key ist bereits als agenix-Secret konfiguriert und wird
als Umgebungsvariable `ANTHROPIC_API_KEY` in den n8n-Prozess injiziert
(via `n8n-setup-env.service` → `/run/n8n/env`).

**Schritt-für-Schritt:**

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Anthropic`**
3. Wähle den Typ **Anthropic** (nicht "Anthropic Chat Model" – das ist ein Node-Typ)
4. Fülle die Felder aus:

| Feld | Wert | Hinweis |
|---|---|---|
| **Credential Name** | `Anthropic Claude` | Frei wählbar |
| **API Key** | `={{ $env.ANTHROPIC_API_KEY }}` | **Expression-Modus aktivieren!** (Klick auf `=` rechts am Feld, dann den Ausdruck eingeben) |

5. Klicke auf **Test Connection** → Muss erfolgreich sein
6. Klicke auf **Save**

> **Wichtig:** Das Feld **API Key** muss im **Expression-Modus** sein
> (erkennbar am orangenen `=`-Symbol neben dem Feld). Im normalen Modus
> wird `{{ $env.ANTHROPIC_API_KEY }}` als Literal-String interpretiert
> und die Authentifizierung schlägt fehl.
>
> **Alternative (falls Expression nicht funktioniert):**
> Den API-Key manuell aus dem Secret auslesen und direkt einfügen:
> ```
> ssh root@10.15.100.10 -- ssh HL-3-RZ-N8N-01 -- cat /run/n8n/env
> ```
> Zeigt `ANTHROPIC_API_KEY=sk-ant-...` – den Wert nach `=` kopieren.

---

### 3. PostgreSQL – Edu-Search (Read-Only)

Zugriff auf die Edu-Search-Datenbank für Benachrichtigungs- und Report-Workflows.
Der User `n8n_reader` hat ausschließlich `SELECT`-Rechte und kann keine Daten
ändern, löschen oder Schemas modifizieren.

**Schritt-für-Schritt:**

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Postgres`**
3. Wähle den Typ **Postgres**
4. Fülle die Felder aus:

| Feld | Wert | Alternativ via Expression |
|---|---|---|
| **Credential Name** | `Edu-Search DB (readonly)` | – |
| **Host** | `10.15.40.114` | `={{ $env.EDU_SEARCH_DB_HOST }}` |
| **Port** | `5432` | `={{ $env.EDU_SEARCH_DB_PORT }}` |
| **Database** | `edu_search` | `={{ $env.EDU_SEARCH_DB_NAME }}` |
| **User** | `n8n_reader` | `={{ $env.EDU_SEARCH_DB_USER }}` |
| **Password** | `edu_n8n_readonly` | – (nicht als Env-Var verfügbar) |
| **SSL** | **Disabled** | Internes Netzwerk (vlan40), kein TLS nötig |

5. Unter **Options** (aufklappen):
   - **Ignore SSL Issues:** ✅ An
6. Klicke auf **Test Connection** → Muss erfolgreich sein
7. Klicke auf **Save**

> **Verfügbar ab:** Erst nachdem die Edu-Search MicroVM live ist (Phase 2).
> Vorher wird der Connection-Test fehlschlagen.

---

### 4. ntfy (Push-Benachrichtigungen)

ntfy wird in den Workflows über einfache HTTP-Request-Nodes angesprochen.
Es gibt keinen dedizierten ntfy-Credential-Typ in n8n v2.6.3. Stattdessen
verwenden wir **Header Auth** für authentifizierte Topics.

**Variante A: Öffentliche Topics (kein Auth nötig)**

Wenn die ntfy-Topics `edu-search` und `homelab` ohne Authentifizierung
beschreibbar sind, braucht kein Credential angelegt zu werden. Die
Workflows senden direkt via HTTP POST an `https://ntfy.czichy.com/<topic>`.

**Variante B: Authentifizierte Topics**

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Header Auth`**
3. Wähle den Typ **Header Auth**
4. Fülle die Felder aus:

| Feld | Wert |
|---|---|
| **Credential Name** | `ntfy Auth` |
| **Header Name** | `Authorization` |
| **Header Value** | `Basic <base64(user:password)>` |

> Den Base64-Wert erzeugen:
> ```
> echo -n "alert:$(cat /run/agenix/ntfy-alert-pass)" | base64
> ```
> Alternativ: Im HTTP-Request-Node direkt Basic Auth verwenden
> (Authentication → "Basic Auth" → User: `alert`, Password: aus Secret).

**In den Workflows verwendet:**

Die Workflows nutzen HTTP-Request-Nodes mit folgender Konfiguration:
- **Method:** POST
- **URL:** `https://ntfy.czichy.com/<topic>` (z.B. `edu-search`, `homelab`)
- **Headers:** `Title`, `Priority`, `Tags`, `Markdown: yes`
- **Body:** Die formatierte Nachricht als String

Jeder Workflow hat die ntfy-URL und den Topic direkt im Node konfiguriert –
kein separates Credential nötig, sofern die Topics öffentlich beschreibbar sind.

---

### 5. Paperless-ngx API (Phase 1: Auto-Tagging)

Paperless-ngx stellt eine REST-API bereit, die mit einem API-Token
authentifiziert wird.

**Schritt 1: API-Token in Paperless erzeugen**

1. Öffne `https://paperless.czichy.com`
2. Melde dich als Admin an
3. Gehe zu **Einstellungen** (⚙️ oben rechts) → **Benutzer & Gruppen**
4. Wähle deinen Benutzer → **API-Token** → **Token generieren**
5. Token kopieren (Format: `abc123def456...`)

**Schritt 2: Credential in n8n anlegen**

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Header Auth`**
3. Wähle den Typ **Header Auth**
4. Fülle die Felder aus:

| Feld | Wert |
|---|---|
| **Credential Name** | `Paperless API` |
| **Header Name** | `Authorization` |
| **Header Value** | `Token <dein-paperless-api-token>` |

5. Klicke auf **Save**

> **Hinweis:** Zwischen `Token` und dem eigentlichen Token-Wert steht ein Leerzeichen.
> Beispiel: `Token abc123def456789ghijklmnop`

---

### 6. IBKR Flex API (Phase 1: Trading-Report)

Die IBKR Flex API verwendet einen Token als Query-Parameter (kein Header).
Der Token wird direkt im HTTP-Request-Node als Query-Parameter übergeben.

**Option A: Direkt im Workflow (einfachste Variante)**

Der IBKR Flex Token wird direkt im Workflow-Node als Query-Parameter konfiguriert.
Nach dem Import des Workflows den Token im Node "IBKR – Flex Report anfordern"
im Query-Parameter `t` eintragen.

**Option B: Via Umgebungsvariable (sicherer)**

1. Den Token als Umgebungsvariable zum n8n-Service hinzufügen (in `n8n.nix`):
   ```nix
   # In services.n8n.environment ergänzen:
   IBKR_FLEX_TOKEN = "dein-ibkr-flex-token";
   ```
2. Im Workflow-Node den Query-Parameter `t` als Expression setzen:
   `={{ $env.IBKR_FLEX_TOKEN }}`

**IBKR-spezifische Werte:**

| Parameter | Wert | Beschreibung |
|---|---|---|
| **Token** | Aus bestehendem Secret `ibkrFlexToken` | IBKR Account Management → Reports → Flex Queries → Token |
| **Query ID** | `639991` | ID der konfigurierten Flex Query in IBKR |
| **API-Version** | `3` | Flex API v3 |

---

### 7. Grafana API (Phase 1: Wöchentliche Zusammenfassung)

Für den Wöchentlichen KI-Report wird die Grafana-API abgefragt.

**Schritt 1: Service-Account in Grafana erzeugen**

1. Öffne `https://grafana.czichy.com`
2. Gehe zu **Administration** → **Service Accounts** → **+ Add Service Account**
3. Name: `n8n-readonly`, Role: **Viewer**
4. Klicke auf **Create** → dann **Add Service Account Token** → **Generate Token**
5. Token kopieren (wird nur einmal angezeigt!)

**Schritt 2: Credential in n8n anlegen**

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Header Auth`**
3. Wähle den Typ **Header Auth**
4. Fülle die Felder aus:

| Feld | Wert |
|---|---|
| **Credential Name** | `Grafana API` |
| **Header Name** | `Authorization` |
| **Header Value** | `Bearer <dein-grafana-service-account-token>` |

5. Klicke auf **Save**

### 8. Parseable API (Phase 1: Log-Daten für Wochenreport)

1. **Credentials** → **+ Add Credential**
2. Suche nach **`Basic Auth`**
3. Wähle den Typ **HTTP Basic Auth**
4. Fülle die Felder aus:

| Feld | Wert |
|---|---|
| **Credential Name** | `Parseable API` |
| **User** | Parseable Admin-User |
| **Password** | Parseable Admin-Passwort |

5. Klicke auf **Save**

---

## Workflow-Import (n8n Community v2.6.3)

### Schritt 1: Credentials anlegen

Alle oben genannten Credentials in der n8n-UI anlegen.
Mindestens **Ollama HOST-01** und **Anthropic Claude** müssen vorhanden sein,
bevor Phase-1-Workflows importiert werden.

### Schritt 2: Workflow-JSON importieren

1. Öffne `https://n8n.czichy.com`
2. Klicke links in der Sidebar auf **Workflows**
3. Klicke oben rechts auf **⋮** (Drei-Punkte-Menü) → **Import from File**
4. Wähle die gewünschte `.json`-Datei aus diesem Verzeichnis
5. Der Workflow öffnet sich im Canvas-Editor

### Schritt 3: Credentials zuweisen

Nach dem Import müssen die Credentials den Nodes zugewiesen werden:

1. Klicke auf jeden Node, der ein **⚠️ Warnsymbol** oder ein **🔑 Schlüssel-Symbol** zeigt
2. Im Node-Editor: Klicke auf das Dropdown-Feld **Credential to connect with**
3. Wähle das passende Credential aus der Liste:
   - Ollama-Nodes → `Ollama HOST-01`
   - Anthropic-Nodes → `Anthropic Claude`
   - PostgreSQL-Nodes → `Edu-Search DB (readonly)`
   - HTTP-Request-Nodes mit Paperless → `Paperless API`
   - HTTP-Request-Nodes mit Grafana → `Grafana API`
   - HTTP-Request-Nodes mit Parseable → `Parseable API`
4. Klicke auf **Save** im Node

> **Tipp:** In n8n v2.6.3 zeigt der Canvas-Editor Nodes mit fehlenden
> Credentials als rot/orange markiert an. Arbeite alle markierten Nodes ab,
> bevor du den Workflow aktivierst.

### Schritt 4: Workflow aktivieren & testen

1. Klicke oben rechts auf den **Inactive/Active Toggle** → auf **Active** stellen
2. Zum manuellen Testen: Klicke auf **Test Workflow** (Play-Button oben)
3. Prüfe im **Execution Log** (linke Sidebar → Executions) ob alle Nodes grün sind
4. Prüfe ob ntfy-Benachrichtigungen auf dem Handy/Browser ankommen

> **Bei Fehlern:** Klicke auf den fehlgeschlagenen Node im Execution-Log.
> n8n v2.6.3 zeigt die Input-/Output-Daten und die Fehlermeldung direkt an.

---

## Netzwerk-Übersicht (vlan40)

```text
n8n (HL-3-RZ-N8N-01, 10.15.40.39:5678)
  │
  ├──► Ollama HOST-01 (10.15.40.10:11434)     ← GPU/CUDA, keine Auth
  ├──► Edu-Search PG (10.15.40.114:5432)      ← n8n_reader, SELECT only
  ├──► Paperless (10.15.40.16:28981)           ← Header Auth (API Token)
  ├──► Grafana (10.15.40.111:3000)             ← Header Auth (Service Account Token)
  ├──► VictoriaMetrics (10.15.40.112:8428)     ← keine Auth
  ├──► InfluxDB (10.15.40.12:8086)             ← Token
  ├──► Parseable (10.15.40.18:8000)            ← Basic Auth
  ├──► Home Assistant (10.15.40.36:8123)       ← Long-Lived Access Token
  └──► Anthropic API (api.anthropic.com:443)   ← API Key (Cloud, via HTTPS)
```

---

## Workflow-Versionierung

n8n-Workflows sind **Zustand** (gespeichert in `/var/lib/n8n/database.sqlite`),
nicht deklarativ wie Nix. Um Reproduzierbarkeit sicherzustellen:

1. **Backup:** Restic sichert `/var/lib/n8n` täglich um 03:00 nach OneDrive
2. **Git-Export:** Nach jeder größeren Workflow-Änderung die JSON-Datei exportieren
   und in dieses Verzeichnis committen
3. **Namenskonvention:** `phase{N}-{kurzbeschreibung}.json`

### Export-Anleitung (n8n Community v2.6.3)

1. Öffne den Workflow in der n8n-UI
2. Klicke oben rechts auf **⋮** (Drei-Punkte-Menü)
3. Klicke auf **Download**
4. Die JSON-Datei wird heruntergeladen
5. Ablegen in `hosts/HL-1-MRZ-HOST-01/guests/n8n-workflows/`
6. `git add` + `git commit`

> **Achtung:** Exportierte Workflows enthalten **keine Credential-Werte**
> (Passwörter, API-Keys). Beim Import auf einer neuen Instanz müssen die
> Credentials neu angelegt und zugewiesen werden.

---

## Abhängigkeiten

| Phase | Voraussetzung | Status |
|---|---|---|
| Phase 0.1 | NVIDIA-Treiber + Ollama nativ auf HOST-01 | ✅ `gpu.nix` + `ollama.nix` |
| Phase 0.2 | Ollama-Credential in n8n-UI anlegen | 🔧 Manuell (Anleitung Abschnitt 1) |
| Phase 0.3 | Anthropic-Credential in n8n-UI anlegen | 🔧 Manuell (Anleitung Abschnitt 2) |
| Phase 1 | Ollama erreichbar + Paperless API-Token + Grafana Token | 🔧 Nach Phase 0 |
| Phase 2 | Edu-Search MicroVM live + PG erreichbar | 🔧 Nach PLAN_EDU_SEARCH Go-Live |

---

## Troubleshooting (n8n Community v2.6.3)

### "Connection refused" bei Ollama

- Prüfe ob Ollama auf HOST-01 läuft: `ssh root@10.15.100.10 -- systemctl status ollama`
- Prüfe ob die Firewall den Port freigibt: `ssh root@10.15.100.10 -- ss -tlnp | grep 11434`
- Prüfe ob n8n die IP erreicht: `ssh root@10.15.100.10 -- ssh HL-3-RZ-N8N-01 -- curl -s http://10.15.40.10:11434`

### "Connection refused" bei Edu-Search PostgreSQL

- Prüfe ob die Edu-Search MicroVM läuft: `ssh root@10.15.100.10 -- microvm -s | grep edu-search`
- Prüfe ob PostgreSQL lauscht: `ssh root@10.15.100.10 -- ssh HL-3-RZ-EDU-01 -- ss -tlnp | grep 5432`
- Prüfe pg_hba: `ssh root@10.15.100.10 -- ssh HL-3-RZ-EDU-01 -- cat /var/lib/postgresql/16/data/pg_hba.conf | grep n8n`

### Expression `{{ $env.VARIABLE }}` funktioniert nicht

- Stelle sicher, dass das Feld im **Expression-Modus** ist (oranges `=`-Symbol)
- In n8n v2.6.3: Klicke auf das kleine `=`-Symbol rechts neben dem Eingabefeld
- Erst danach die Expression `={{ $env.ANTHROPIC_API_KEY }}` eingeben
- Das führende `=` gehört zur Syntax und aktiviert den Expression-Parser

### Workflows zeigen nach Import alle Nodes als fehlerhaft

- Das ist normal – nach dem Import müssen alle Credentials zugewiesen werden
- Siehe Abschnitt "Schritt 3: Credentials zuweisen" oben