# 🔐 Kanidm – Zentrales Identity & Access Management

## SSO für alle Services via OAuth2/OpenID Connect

> **Ziel:** Kanidm als zentrale Authentifizierungslösung auf HOST-02 als MicroVM.
> Alle externen Services (edu-search, grafana, forgejo, paperless, immich, etc.)
> werden über OAuth2/OIDC abgesichert. Ina und Christian loggen sich einmal ein
> und haben Zugriff auf alle freigegebenen Services.

---

## Architektur-Übersicht

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                                 │                                            │
│                    ┌────────────▼────────────────┐                           │
│                    │   HL-4-PAZ-PROXY-01 (VPS)   │                           │
│                    │   Caddy + oauth2-proxy       │                           │
│                    │     ↕ WireGuard Tunnel       │                           │
│                    └────────────┬────────────────┘                           │
│                                 │                                            │
│                    ┌────────────▼────────────────┐                           │
│                    │  vlan70 (DMZ)                │                           │
│                    │  HL-3-DMZ-PROXY-01 (Caddy)  │                           │
│                    └────────────┬────────────────┘                           │
│                                 │                                            │
│  ┌──────────────────────────────▼──────────────────────────────────────────┐ │
│  │                        vlan40 (Server-VLAN)                             │ │
│  │                                                                         │ │
│  │  ┌─────────────────────────────────────────┐                            │ │
│  │  │      HL-1-MRZ-HOST-02 (Topton, 16GB)    │                            │ │
│  │  │      .20 in vlan40                       │                            │ │
│  │  │                                          │                            │ │
│  │  │  ● MicroVM: kanidm (.115)                │                            │ │
│  │  │    Kanidm Server :8443 (HTTPS)           │                            │ │
│  │  │    OAuth2/OIDC Provider                  │                            │ │
│  │  │    auth.czichy.com                       │                            │ │
│  │  │                                          │                            │ │
│  │  │  + adguardhome, vaultwarden, caddy       │                            │ │
│  │  └─────────────────────────────────────────┘                            │ │
│  │                                                                         │ │
│  │  ┌─────────────────────────────────────────┐                            │ │
│  │  │      HL-1-MRZ-HOST-01 (Ryzen, 64GB)     │                            │ │
│  │  │      .10 in vlan40                       │                            │ │
│  │  │                                          │                            │ │
│  │  │  ● Ollama (nativ, GPU) :11434            │                            │ │
│  │  │  ● edu-search (.114) :8080               │                            │ │
│  │  │  ● grafana, forgejo, paperless, ...      │                            │ │
│  │  └─────────────────────────────────────────┘                            │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Authentifizierungs-Fluss (Services OHNE eigene OAuth2-Integration)

Gilt für: **edu-search**, adguardhome, open-webui (über web-sentinel / oauth2-proxy)

```text
Browser (Ina) → https://edu.czichy.com
    │
    ▼
HL-4-PAZ-PROXY-01 (Caddy + forward_auth → oauth2-proxy)
    │ Hat der Nutzer ein gültiges Session-Cookie?
    │
    ├─ NEIN → Redirect zu https://auth.czichy.com/ui/oauth2
    │            │
    │            ▼
    │         Kanidm Login-Seite (HL-3-RZ-AUTH-01)
    │            │ Nutzer gibt Benutzername + Passwort ein
    │            ▼
    │         Kanidm prüft Gruppenmitgliedschaft (web-sentinel.edu-search)
    │            │ OK → OAuth2 Authorization Code → Redirect zurück
    │            ▼
    │         oauth2-proxy tauscht Code gegen Token → Session-Cookie setzen
    │
    └─ JA → Weiterleitung an den Backend-Service
              │
              ▼
         HL-1-MRZ-HOST-02-caddy → edu-search MicroVM :8080
```

### Authentifizierungs-Fluss (Services MIT eigener OAuth2-Integration)

Gilt für: **grafana**, forgejo, paperless, immich, linkwarden

```text
Browser → https://grafana.czichy.com → Grafana Login-Seite
    │ Klick auf "Login with Kanidm"
    ▼
Redirect zu https://auth.czichy.com/oauth2/openid/grafana
    │ Login + Autorisierung
    ▼
Redirect zurück zu Grafana mit Authorization Code
    │ Grafana tauscht Code gegen Token direkt mit Kanidm
    ▼
Eingeloggt (Rollen via Kanidm-Gruppen: grafana.editors, grafana.admins, etc.)
```

---

## Erstellte Dateien

| Datei | Beschreibung |
|---|---|
| `hosts/HL-1-MRZ-HOST-02/guests/kanidm.nix` | Kanidm MicroVM Konfiguration |
| `hosts/HL-1-MRZ-HOST-02/guests.nix` | Geändert: kanidm MicroVM registriert |
| `globals.nix` | Geändert: `HL-3-RZ-AUTH-01.id = 115` + `kanidm.persons` |

---

## Benutzer & Gruppen (definiert in `globals.nix`)

### Benutzer

| Person | Mail | Zugriff |
|---|---|---|
| **christian** | christian@czichy.com | Alle Services, überall Admin |
| **ina** | ina@czichy.com | edu-search, paperless, immich, linkwarden |

### Gruppen-Übersicht

| Gruppe | Zweck | Mitglieder |
|---|---|---|
| `edu-search.access` | Zugang zu edu-search | christian, ina |
| `grafana.access` | Zugang zu Grafana | christian |
| `grafana.admins` | Grafana Admin-Rolle | christian |
| `grafana.server-admins` | Grafana Server-Admin | christian |
| `grafana.editors` | Grafana Editor-Rolle | — (über admins implizit) |
| `forgejo.access` | Zugang zu Forgejo | christian |
| `forgejo.admins` | Forgejo Admin-Rolle | christian |
| `paperless.access` | Zugang zu Paperless | christian, ina |
| `immich.access` | Zugang zu Immich | christian, ina |
| `linkwarden.access` | Zugang zu Linkwarden | christian, ina |
| `linkwarden.admins` | Linkwarden Admin-Rolle | christian |
| `open-webui.access` | Zugang zu Open-WebUI | christian |
| `web-sentinel.access` | OAuth2-Proxy Basiszugang | christian, ina |
| `web-sentinel.edu-search` | Edu-Search via Proxy | christian, ina |
| `web-sentinel.adguardhome` | AdGuard Home via Proxy | christian |
| `web-sentinel.open-webui` | Open-WebUI via Proxy | christian |

---

## Secrets-Management

### Benötigte Secrets (alle im private-Repo unter `hosts/HL-1-MRZ-HOST-02/guests/kanidm/`)

Alle Secrets sind mit `builtins.pathExists` abgesichert. Fehlende Secrets deaktivieren den
jeweiligen Konfigurations-Block, der Build schlägt **nicht** fehl.

#### TLS-Zertifikat (Kanidm erzwingt TLS, auch intern)

```bash
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /tmp/kanidm.key -out /tmp/kanidm.crt \
  -subj "/CN=auth.czichy.com" \
  -addext "subjectAltName=DNS:auth.czichy.com"

agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.crt.age < /tmp/kanidm.crt
agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.key.age < /tmp/kanidm.key
rm /tmp/kanidm.key /tmp/kanidm.crt
```

#### Admin-Passwörter

```bash
openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/admin-password.age
openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/idm-admin-password.age
```

#### OAuth2 Client-Secrets (eines pro Service)

```bash
for svc in edu-search grafana forgejo paperless immich linkwarden open-webui web-sentinel; do
  openssl rand -base64 32 | \
    agenix -e "hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-${svc}.age"
done
```

### Secret-Dateien Übersicht

| Datei | Pflicht | Zweck |
|---|---|---|
| `kanidm-self-signed.crt.age` | ✅ | TLS-Zertifikat (Self-Signed) |
| `kanidm-self-signed.key.age` | ✅ | TLS-Schlüssel |
| `admin-password.age` | ✅ | Kanidm `admin` Passwort |
| `idm-admin-password.age` | ✅ | Kanidm `idm_admin` Passwort |
| `oauth2-edu-search.age` | Optional | OAuth2 Client-Secret für edu-search |
| `oauth2-grafana.age` | Optional | OAuth2 Client-Secret für Grafana |
| `oauth2-forgejo.age` | Optional | OAuth2 Client-Secret für Forgejo |
| `oauth2-paperless.age` | Optional | OAuth2 Client-Secret für Paperless |
| `oauth2-immich.age` | Optional | OAuth2 Client-Secret für Immich |
| `oauth2-linkwarden.age` | Optional | OAuth2 Client-Secret für Linkwarden |
| `oauth2-open-webui.age` | Optional | OAuth2 Client-Secret für Open-WebUI |
| `oauth2-web-sentinel.age` | Optional | OAuth2 Client-Secret für oauth2-proxy |

---

## Netzwerk

```text
vlan40 (10.15.40.0/24)
├── .10   HL-1-MRZ-HOST-01      (Ollama :11434, MicroVM-Host)
├── .20   HL-1-MRZ-HOST-02      (MicroVM-Host)
├── .115  HL-3-RZ-AUTH-01  ← NEU (Kanidm :8443, auth.czichy.com)
├── .21   HL-3-RZ-DNS-01        (AdGuard Home)
├── .22   HL-3-RZ-VAULT-01      (Vaultwarden)
├── .114  HL-3-RZ-EDU-01        (Edu-Search :8080)
├── .111  HL-3-RZ-GRAFANA-01    (Grafana)
├── .14   HL-3-RZ-GIT-01        (Forgejo)
├── .16   HL-3-RZ-PAPERLESS-01  (Paperless)
└── ...

Datenflüsse:
  alle Services ──HTTPS:8443──→ AUTH-01 (Kanidm OAuth2/OIDC)
  PAZ-PROXY-01 ──HTTPS:8443──→ AUTH-01 (oauth2-proxy Validierung)
  Browser       ──HTTPS──────→ auth.czichy.com (Login-Seite)
```

---

## Rollout-Plan

### Phase 1 – Kanidm deployen (Wochenende 1)

1. [ ] Secrets erzeugen (TLS-Cert + Admin-Passwörter)
2. [ ] `nixos-rebuild` auf HOST-02
3. [ ] Kanidm MicroVM starten
4. [ ] `https://auth.czichy.com` erreichbar prüfen
5. [ ] Admin-Login testen: `kanidm login --name admin`
6. [ ] Prüfen ob christian/ina Benutzer provisioniert wurden

### Phase 2 – oauth2-proxy anbinden (Wochenende 1)

1. [ ] OAuth2 Client-Secret für `web-sentinel` erzeugen
2. [ ] `oauth2.nix` auf PAZ-PROXY-01 anpassen: `ward-kanidm` → `HL-1-MRZ-HOST-02-kanidm`
3. [ ] Deploy auf PAZ-PROXY-01
4. [ ] OAuth2-Login-Flow testen

### Phase 3 – edu-search absichern (Wochenende 2)

1. [ ] Deploy auf HOST-01 (edu-search mit `forward_auth`)
2. [ ] `https://edu.czichy.com` → Kanidm-Login → Suche testen
3. [ ] Ina testen lassen

### Phase 4 – Weitere Services anbinden (Wochenende 2-3)

1. [ ] Grafana OAuth2 aktivieren (Secret erzeugen, Grafana-Config anpassen)
2. [ ] Forgejo OAuth2 aktivieren
3. [ ] Paperless: `nodes.ward-kanidm` → `nodes.HL-1-MRZ-HOST-02-kanidm`
4. [ ] Immich: `nodes.ward-kanidm` → `nodes.HL-1-MRZ-HOST-02-kanidm`
5. [ ] Linkwarden OAuth2 aktivieren
6. [ ] Open-WebUI über web-sentinel absichern

---

## Zu ändernde bestehende Dateien (Phase 3+)

| Datei | Änderung | Prio |
|---|---|---|
| `HL-4-PAZ-PROXY-01/oauth2.nix` | `nodes.ward-kanidm` → `nodes.HL-1-MRZ-HOST-02-kanidm` | Hoch |
| `guests/paperless.nix` | `nodes.ward-kanidm` → `nodes.HL-1-MRZ-HOST-02-kanidm` | Hoch |
| `guests/immich.nix` | `nodes.ward-kanidm` → `nodes.HL-1-MRZ-HOST-02-kanidm` | Hoch |
| `guests/grafana.nix` | Kanidm OAuth2 Client konfigurieren | Mittel |
| `guests/forgejo.nix` | Kanidm OAuth2 aktivieren (Code ist auskommentiert) | Mittel |
| `guests/linkwarden.nix` | Client-Secret Referenz auf Kanidm-Node anpassen | Mittel |
| `guests/ai.nix` | Refactoring: Ollama raus, Open-WebUI → HOST-01:11434 | Niedrig |