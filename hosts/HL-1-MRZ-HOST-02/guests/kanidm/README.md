# Kanidm – Identity & Access Management

Kanidm läuft als MicroVM (`HL-3-RZ-AUTH-01`) auf `HL-1-MRZ-HOST-02` und stellt
OAuth2/OIDC-basiertes Single Sign-On für alle Services bereit.

**Web-UI:** https://auth.czichy.com

---

## Architektur

```
INTERNET
    │
    ▼
HL-4-PAZ-PROXY-01 (VPS)          Caddy + oauth2-proxy
    │ WireGuard Tunnel
    ▼
HL-3-DMZ-PROXY-01 (Caddy)
    │
    ▼
HL-1-MRZ-HOST-02 (vlan40, .20)
    └── MicroVM: HL-3-RZ-AUTH-01 (.115)
            Kanidm :8443 (HTTPS)
            auth.czichy.com
```

Kanidm erzwingt TLS auch intern. Es wird ein Self-Signed-Zertifikat verwendet,
das via agenix verwaltet wird. Der externe Zugang läuft über Caddy mit echtem
Let's-Encrypt-Zertifikat.

---

## Benutzer & Zugriff

Benutzer werden deklarativ in `globals.nix` unter `kanidm.persons` definiert.
Passwörter werden **nicht** in der Konfiguration gespeichert — sie müssen nach
dem ersten Deploy manuell gesetzt werden (siehe unten).

| Benutzer | E-Mail | Rolle |
|---|---|---|
| `christian` | christian@czichy.com | Admin auf allen Services |
| `ina` | ina@czichy.com | Zugriff auf edu-search |

### Gruppen

| Gruppe | Zweck | Mitglieder |
|---|---|---|
| `edu-search.access` | Zugang zu edu-search | christian, ina |
| `grafana.access` | Zugang zu Grafana | christian |
| `grafana.editors` | Grafana Editor-Rolle | — |
| `grafana.admins` | Grafana Admin-Rolle | christian |
| `grafana.server-admins` | Grafana Server-Admin | christian |
| `forgejo.access` | Zugang zu Forgejo | christian |
| `forgejo.admins` | Forgejo Admin-Rolle | christian |
| `web-sentinel.access` | oauth2-proxy Basiszugang | christian, ina |
| `web-sentinel.edu-search` | edu-search via Proxy | christian, ina |

---

## Login-Flows

### Services mit nativer OAuth2-Integration (Grafana, Forgejo)

```
Browser → https://grafana.czichy.com
    │ Klick auf "Login with Kanidm"
    ▼
Redirect → https://auth.czichy.com/oauth2/openid/grafana
    │ Login + Autorisierung
    ▼
Redirect zurück zu Grafana mit Authorization Code
    │ Grafana tauscht Code gegen Token direkt mit Kanidm
    ▼
Eingeloggt (Rollen via Kanidm-Gruppen: grafana.editors, grafana.admins, ...)
```

### Services ohne OAuth2 (edu-search, geschützt via oauth2-proxy)

```
Browser → https://edu.czichy.com
    │
    ▼
HL-4-PAZ-PROXY-01 (Caddy + forward_auth → oauth2-proxy)
    │ Hat der Nutzer ein gültiges Session-Cookie?
    │
    ├─ NEIN → Redirect zu https://auth.czichy.com/ui/oauth2
    │              Kanidm Login-Seite
    │              Prüfung Gruppenmitgliedschaft (web-sentinel.edu-search)
    │              OK → Session-Cookie setzen → Redirect zurück
    │
    └─ JA → Weiterleitung an edu-search Backend
```

---

## Erstes Setup

### 1. Secrets erzeugen

```bash
# Automatisch (idempotent, überspringt vorhandene Secrets):
nu scripts/generate-kanidm-secrets.nu <secrets-repo-pfad>

# Mit Host-Keys für direkte age-Verschlüsselung:
nu scripts/generate-kanidm-secrets.nu ~/nix-secrets \
  --host02-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPR8KYYsWTQ..."

# Dry-run (zeigt was erzeugt würde):
nu scripts/generate-kanidm-secrets.nu ~/nix-secrets --dry-run
```

Ohne `--host02-key` oder `--recipient-file` werden die Secrets als Plaintext
nach `/tmp/kanidm-secrets/` geschrieben und müssen manuell mit `age` verschlüsselt
werden.

#### Manuell (alternativ)

```bash
# TLS-Zertifikat (Self-Signed, 10 Jahre gültig):
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout /tmp/kanidm.key -out /tmp/kanidm.crt \
  -subj "/CN=auth.czichy.com" \
  -addext "subjectAltName=DNS:auth.czichy.com"
agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.crt.age < /tmp/kanidm.crt
agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/kanidm-self-signed.key.age < /tmp/kanidm.key
rm /tmp/kanidm.key /tmp/kanidm.crt

# Admin-Passwörter:
openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/admin-password.age
openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/idm-admin-password.age

# OAuth2 Client-Secrets (aktive Services):
for svc in grafana forgejo web-sentinel; do
  openssl rand -base64 32 | \
    agenix -e "hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-${svc}.age"
done

# Restic-Backup-Passwort:
openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/restic-kanidm.age
```

### 2. Deployen

```bash
nixos-rebuild switch --flake .#HL-1-MRZ-HOST-02
```

> Fehlen Secrets beim Build, gibt NixOS eine Warnung aus — der Build schlägt
> **nicht** fehl. Kanidm wird in diesem Fall deaktiviert.

### 3. Benutzerpasswörter setzen

Kanidm speichert keine Benutzerpasswörter in der NixOS-Konfiguration.
Nach dem ersten Deploy müssen Passwörter über `idm_admin` gesetzt werden:

```bash
# Als idm_admin einloggen (Passwort aus admin-password.age):
kanidm login --name idm_admin --url https://auth.czichy.com

# Reset-Token generieren (Benutzer setzt Passwort selbst über Web-UI):
kanidm person credential create-reset-token christian
kanidm person credential create-reset-token ina

# Oder direkt per CLI:
kanidm person credential set-password christian
```

Den Reset-Link unter `https://auth.czichy.com/ui/reset` im Browser öffnen.

---

## Secrets-Übersicht

Alle Secrets liegen im private-Repo unter:
`hosts/HL-1-MRZ-HOST-02/guests/kanidm/`

| Datei | Pflicht | Zweck |
|---|---|---|
| `kanidm-self-signed.crt.age` | Ja | TLS-Zertifikat (Self-Signed) |
| `kanidm-self-signed.key.age` | Ja | TLS-Schlüssel |
| `admin-password.age` | Ja | Kanidm `admin` Passwort |
| `idm-admin-password.age` | Ja | Kanidm `idm_admin` Passwort |
| `oauth2-grafana.age` | Optional | OAuth2 Client-Secret für Grafana |
| `oauth2-forgejo.age` | Optional | OAuth2 Client-Secret für Forgejo |
| `oauth2-web-sentinel.age` | Optional | OAuth2 Client-Secret für oauth2-proxy |
| `restic-kanidm.age` | Optional | Restic-Backup-Passwort |

OAuth2-Secrets werden **doppelt** gespeichert: einmal für Kanidm (HOST-02)
und einmal für den jeweiligen Consumer-Service (HOST-01 / PAZ-PROXY-01).

---

## Backup

Kanidm erstellt täglich konsistente JSON-Dumps (`online_backup`).
Restic sichert diese Dumps anschließend via rclone nach OneDrive.

| Zeit | Aktion |
|---|---|
| 02:00 UTC | Kanidm `online_backup` → `/var/lib/kanidm/backups/` |
| 02:30 UTC | Restic → `rclone:onedrive_nas:/backup/HL-3-RZ-AUTH-01-kanidm` |

Aufbewahrung: 14 Snapshots. Benachrichtigung bei Erfolg/Fehler via ntfy.

---

## Neuen Service anbinden

### Mit nativer OAuth2-Unterstützung

1. Gruppe in `globals.nix` unter `kanidm.persons` hinzufügen
2. OAuth2-Secret erzeugen:
   ```bash
   openssl rand -base64 32 | agenix -e hosts/HL-1-MRZ-HOST-02/guests/kanidm/oauth2-<service>.age
   ```
3. In `kanidm.nix` unter `provision.groups` und `provision.systems.oauth2.<service>` eintragen
4. In der Service-Konfiguration den OIDC-Client konfigurieren

### Ohne OAuth2 (via oauth2-proxy)

1. Untergruppe `web-sentinel.<service>` in `globals.nix` und `kanidm.nix` hinzufügen
2. In `hosts/HL-4-PAZ-PROXY-01/oauth2.nix` einen neuen `upstream` mit
   `allowed_groups` konfigurieren

---

## Netzwerk

```
vlan40 (10.15.40.0/24)
├── .10   HL-1-MRZ-HOST-01   (MicroVM-Host, Grafana, Forgejo, ...)
├── .20   HL-1-MRZ-HOST-02   (MicroVM-Host, Kanidm-Parent)
└── .115  HL-3-RZ-AUTH-01    (Kanidm MicroVM :8443)
```

- MicroVM: 1 GB RAM, 2 vCPUs
- Port: `8443` (HTTPS, auch intern)
- Health-Check: `https://10.15.40.115:8443/status`

---

## Relevante Dateien

| Datei | Beschreibung |
|---|---|
| `hosts/HL-1-MRZ-HOST-02/guests/kanidm.nix` | Kanidm MicroVM Konfiguration |
| `hosts/HL-1-MRZ-HOST-02/guests.nix` | MicroVM-Registrierung |
| `globals.nix` (Z. 170–221) | Benutzer- und Gruppendefinitionen |
| `hosts/HL-4-PAZ-PROXY-01/oauth2.nix` | oauth2-proxy Konfiguration |
| `scripts/generate-kanidm-secrets.nu` | Secret-Generator (idempotent) |
| `PLAN_KANIDM.md` | Architektur & Rollout-Plan |
