# NixOS Homelab - Umfassende Projektdokumentation

> **Erstellt am:** 2026-01-13  
> **Projekt:** czichy's NixOS Homelab Konfiguration  
> **Beschreibung:** Professionelle Homelab-Infrastruktur mit Sicherheitszonen, MicroVM-Orchestrierung und verteilten Services

---

## 📋 Inhaltsverzeichnis

1. [Projekt-Übersicht](#-projekt-übersicht)
2. [Architektur-Überblick](#-architektur-überblick)
3. [Verzeichnisstruktur](#-verzeichnisstruktur)
4. [Hosts & Systeme](#-hosts--systeme)
5. [Netzwerk-Architektur](#-netzwerk-architektur)
6. [Services & Anwendungen](#-services--anwendungen)
7. [Module & Konfiguration](#-module--konfiguration)
8. [Besondere Features](#-besondere-features)
9. [Installation & Deployment](#-installation--deployment)
10. [Wartung & Betrieb](#-wartung--betrieb)
11. [Sicherheit](#-sicherheit)
12. [Backup & Recovery](#-backup--recovery)

---

## 🎯 Projekt-Übersicht

### Was ist dieses Projekt?

Dies ist eine **professionelle, produktionsreife NixOS-Konfiguration** für eine vollständige Homelab-Infrastruktur mit:

- **6 physische/virtuelle Hosts** über 4 Sicherheitszonen verteilt
- **30+ MicroVM-Gäste** mit containerisierten Services
- **Professionelle Netzwerk-Zonierung** mit VLAN-Segmentierung
- **Enterprise-Grade Sicherheit** mit Verschlüsselung und Secrets Management
- **Erweiterte Storage-Lösung** mit ZFS und Impermanence
- **Vollständiger Home Automation Stack**
- **Selbst-gehostete Alternativen** zu Cloud-Services
- **Monitoring & Observability** Infrastruktur
- **Hybrid-Cloud-Architektur** mit VPS-Proxy für externen Zugriff

### Philosophie

Die Konfiguration basiert auf den Prinzipien von:

- **Deklarativ & Reproduzierbar**: Alles ist Code, alles ist versioniert
- **Opt-in Architektur**: Module sind standardmäßig deaktiviert
- **Security by Design**: Zonierung nach ITSG-22/ITSG-38 Standards
- **Minimal & Fokussiert**: Nur das Nötigste, keine Über-Engineering

---

## 🏗️ Architektur-Überblick

### Technologie-Stack

**Core:**
- NixOS (unstable channel)
- Nix Flakes
- flake-parts (modulare Flake-Konstruktion)
- Home-manager

**Virtualisierung:**
- microvm.nix (lightweight VMs)
- ZFS (Storage)
- macvtap (Networking)

**Sicherheit:**
- agenix (Secrets Management)
- nftables (Firewall)
- Wireguard (VPN)
- LUKS (Disk Encryption)

**Monitoring:**
- InfluxDB (Metrics)
- Grafana (Visualization)
- Telegraf (Collection)
- Parseable (Logs)

### Infrastruktur-Diagramm

```
                    Internet
                       |
              [HL-4-PAZ-PROXY-01]
                  (VPS Proxy)
                       |
                   Wireguard
                       |
              [HL-3-MRZ-FW-01]
                  (OPNSense)
                       |
        +---------------+---------------+
        |               |               |
   VLAN 10          VLAN 40         VLAN 100
   (Trust)         (Servers)        (Management)
        |               |               |
[HL-1-OZ-PC-01]  [HL-3-DMZ-PROXY-01]  [Hosts]
  (Desktop)       (Caddy Proxy)
                       |
        +---------------+---------------+
        |               |               |
  [HOST-01]       [HOST-02]       [HOST-03]
  12 MicroVMs     4 MicroVMs      5 MicroVMs
```

---

## 📁 Verzeichnisstruktur

### Haupt-Verzeichnisse

```
nixos/
├── flake.nix              # Haupt-Flake mit 40+ Inputs
├── globals.nix            # Zentrale Netzwerk & Infrastruktur Config
├── flake.lock             # Locked Dependencies
│
├── assets/                # Statische Ressourcen
│   ├── certs/            # CA & Zertifikate
│   ├── wallpapers/       # Desktop-Hintergründe
│   ├── icons/            # Icons & Logos
│   └── diagrams/         # Netzwerk-Diagramme
│
├── hosts/                 # Host-Systemkonfigurationen
│   ├── HL-1-OZ-PC-01/    # Desktop Workstation
│   ├── HL-1-MRZ-HOST-01/ # Primary Server (12 VMs)
│   ├── HL-1-MRZ-HOST-02/ # Secondary Server (4 VMs)
│   ├── HL-1-MRZ-HOST-03/ # IoT/Automation Server (5 VMs)
│   ├── HL-4-PAZ-PROXY-01/# Cloud VPS Proxy
│   └── HL-3-MRZ-FW-01/   # Firewall (Partial Config)
│
├── homes/                 # Home-manager Benutzerkonfigurationen
│   ├── czichy@desktop/   # Desktop User Config
│   ├── czichy@server/    # Server User Config
│   └── czichy@minimal/   # Minimal User Config
│
├── modules/               # Modulares Konfigurationssystem
│   ├── nixos/            # NixOS System-Module
│   │   ├── profiles/     # System-Profile (base, server, graphical)
│   │   ├── services/     # Service-Module
│   │   ├── system/       # System-Konfiguration
│   │   └── programs/     # System-Programme
│   └── home-manager/     # Home-Manager Module
│       ├── profiles/     # User-Profile
│       ├── programs/     # User-Programme
│       ├── desktop/      # Desktop-Environment
│       └── services/     # User-Services
│
├── parts/                 # Flake-parts Komponenten
│   ├── apps/             # Nix Apps
│   ├── checks/           # CI Checks
│   ├── lib/              # Extended Library
│   ├── overlays/         # Package Overlays
│   ├── pkgs/             # Custom Packages
│   ├── shells/           # Dev Shells
│   └── templates/        # Project Templates
│
├── topology/              # Netzwerk-Topologie Visualisierung
├── installer/             # Custom NixOS Installer ISO
└── scripts/               # Hilfs-Skripte
```

### Organisations-Muster

**Flake-parts Struktur:**
- Modulare Flake-Konstruktion
- Jeder Teil in separatem Verzeichnis
- Automatisches Laden aller Module
- Opt-in Aktivierung erforderlich

**Module System:**
- Globales Laden, explizite Aktivierung
- Trennung zwischen System und User
- Profile für verschiedene Anwendungsfälle
- Abhängigkeits-Management

---

## 🖥️ Hosts & Systeme

### Namenskonvention

**Format:** `HL-#-ZZZ-FFF-$$`

- **HL**: Homelab
- **#**: Physische Lokalität
  - 1 = Zuhause (physisch)
  - 2 = Offsite (physisch)
  - 3 = VM lokal
  - 4 = Cloud VPS
- **ZZZ**: Sicherheitszone (OZ, RZ, MRZ, DMZ, PAZ)
- **FFF**: Funktion (PC, HOST, PROXY, FW)
- **$$**: Seriennummer (01, 02, ...)

### Aktive Hosts

#### 1. HL-1-OZ-PC-01 (Desktop Workstation)

**Hardware:**
- CPU: AMD Ryzen 9 9950X (16 Cores, 32 Threads)
- GPU: AMD Radeon
- RAM: 64GB+ (geschätzt)
- Storage: ZFS mit Verschlüsselung

**Konfiguration:**
- **Lokalität**: Operations Zone (Trusted)
- **Profil**: graphical-niri
- **Window Manager**: Niri (Wayland Compositor)
- **Features**:
  - Flatpak Support
  - Printing (CUPS)
  - Virtualization (KVM/QEMU)
  - Disko (Disk Management)
  - Impermanence (Ephemeral Root)
- **Home**: czichy@desktop
- **IP-Adressen**:
  - VLAN 10 (Trust): 10.15.10.25
  - VLAN 40 (Server): 10.15.40.25
  - VLAN 100 (Management): 10.15.100.25

**Besonderheiten:**
- Hauptarbeitsstation für Development
- Gaming-fähig (Steam, Minecraft)
- Multiple Shell-Optionen (Nushell, Fish, Zsh)
- Mehrere Editoren (Helix, Zed, Neovim)
- Browser-Auswahl (Zen, Firefox mit Arkenfox, Chromium)

---

#### 2. HL-1-MRZ-HOST-01 (Primary Server)

**Hardware:**
- CPU: Intel N100 (4 Cores)
- RAM: 16GB
- Storage: ZFS Pools (rpool, storage)
- Network: 2.5GbE

**Konfiguration:**
- **Lokalität**: Management Restricted Zone
- **Profil**: server
- **Rolle**: Primärer MicroVM Hypervisor
- **Features**:
  - KEA DHCP Server
  - Wireguard VPN
  - MicroVM Orchestration
  - ZFS Storage Management
- **Home**: czichy@server
- **IP-Adressen**:
  - VLAN 40 (Server): 10.15.40.10
  - VLAN 100 (Management): 10.15.100.10

**MicroVM Gäste (12 Services):**

| VM | Name | Service | IP | Zweck |
|----|------|---------|-----|-------|
| 1 | HL-3-RZ-SMB-01 | Samba | 10.15.40.11 | File Sharing |
| 2 | HL-3-RZ-INFLUX-01 | InfluxDB | 10.15.40.12 | Time-Series DB |
| 3 | HL-3-RZ-SYNC-01 | Syncthing | 10.15.40.13 | File Sync |
| 4 | HL-3-RZ-SYNC-02 | Syncthing (Ina) | 10.15.40.113 | File Sync |
| 5 | HL-3-RZ-GIT-01 | Forgejo | 10.15.40.14 | Git Forge |
| 6 | HL-3-RZ-IBKR-01 | IBKR Flex | 10.15.40.15 | Finance Data |
| 7 | HL-3-RZ-PAPERLESS-01 | Paperless-ngx | 10.15.40.16 | Document Mgmt |
| 8 | HL-3-RZ-ENTE-01 | Ente | 10.15.40.17 | Photo Backup |
| 9 | HL-3-RZ-LOG-01 | Parseable | 10.15.40.18 | Log Aggregation |
| 10 | HL-3-RZ-S3-01 | Minio | 10.15.40.19 | Object Storage |
| 11 | HL-3-RZ-AFFINE-01 | Affine | 10.15.40.110 | Knowledge Base |
| 12 | HL-3-RZ-GRAFANA-01 | Grafana | 10.15.40.111 | Visualization |

**Storage Layout:**
```
rpool/
├── local/              # Ephemeral data
│   ├── root           # System root (wiped on boot)
│   └── nix            # Nix store
├── safe/               # Persistent data
│   ├── home           # User homes
│   ├── persist        # System persistence
│   └── guests/        # VM-specific data
└── bunker/             # Long-term storage
    └── backups        # Backup datasets
```

---

#### 3. HL-1-MRZ-HOST-02 (Secondary Server)

**Hardware:**
- CPU: Topton N5105 (geschätzt)
- RAM: 16GB
- Storage: ZFS

**Konfiguration:**
- **Lokalität**: Management Restricted Zone
- **Profil**: server
- **Rolle**: Infrastruktur-Services
- **IP-Adressen**:
  - VLAN 10 (Trust): 10.15.10.254
  - VLAN 40 (Server): 10.15.40.20
  - VLAN 100 (Management): 10.15.100.20

**MicroVM Gäste (4 Services):**

| VM | Name | Service | IP | Zweck |
|----|------|---------|-----|-------|
| 1 | HL-3-RZ-DNS-01 | AdGuard Home | 10.15.40.21 | DNS & Ad-Blocking |
| 2 | HL-3-RZ-VAULT-01 | Vaultwarden | 10.15.40.22 | Password Manager |
| 3 | HL-3-DMZ-PROXY-01 | Caddy | 10.15.70.1 | Reverse Proxy |
| 4 | - | Nginx | - | Web Server |

---

#### 4. HL-1-MRZ-HOST-03 (IoT/Automation Server)

**Hardware:**
- CPU: ZimaBlade 7700
- RAM: 16GB
- Storage: NVMe + SATA

**Konfiguration:**
- **Lokalität**: Management Restricted Zone
- **Profil**: server
- **Rolle**: Home Automation & IoT
- **IP-Adressen**:
  - VLAN 100 (Management): 10.15.100.30

**MicroVM Gäste (5+ Services):**

| VM | Name | Service | IP | Zweck |
|----|------|---------|-----|-------|
| 1 | HL-3-RZ-HASS-01 | Home Assistant | 10.15.40.36 | Smart Home Hub |
| 2 | HL-3-RZ-MQTT-01 | Mosquitto | 10.15.40.33 | MQTT Broker |
| 3 | HL-3-RZ-RED-01 | Node-RED | 10.15.40.35 | Automation |
| 4 | HL-3-RZ-UNIFI-01 | Unifi Controller | 10.15.40.31 | Network Mgmt |
| 5 | HL-3-RZ-HOME-01 | Homepage | 10.15.40.37 | Dashboard |
| 6 | HL-3-RZ-POWER-02 | Power Meter | 10.15.40.34 | Energy Monitor |
| 7 | HL-3-RZ-MC-01 | Minecraft | 10.15.40.32 | Game Server |

**Home Assistant Features:**
- 15+ Integration-Module
- BME680 Sensoren
- Bluetooth Integration
- Android App Integration
- LDAP Authentication
- Custom Automations (Witze, Timer, Wetter)
- Laptop Tracking
- Charge Notifications

---

#### 5. HL-4-PAZ-PROXY-01 (Cloud VPS)

**Hardware:**
- Provider: NetCup VPS
- CPU: Virtual Cores
- RAM: 2-4GB (geschätzt)
- Storage: SSD

**Konfiguration:**
- **Lokalität**: Cloud Public Access Zone
- **Profil**: server
- **Rolle**: Externer Reverse Proxy & Entry Point
- **IP-Adressen**:
  - Public: (öffentliche IP)
  - Proxy VPN: 10.46.0.90

**Services:**
- **Caddy**: Reverse Proxy mit OAuth2
- **Wireguard**: VPN Tunnel zu Homelab
- **ACME**: Let's Encrypt Zertifikate
- **Uptime Monitoring**: Service Health Checks

**Zweck:**
- Sicherer öffentlicher Zugriff auf interne Services
- SSL Termination
- DDoS Protection
- OAuth2 Authentication Layer

---

#### 6. HL-3-MRZ-FW-01 (Firewall)

**Hardware:**
- Dedicated Firewall Appliance

**Konfiguration:**
- **Software**: OPNSense (nicht NixOS)
- **Lokalität**: Management Restricted Zone
- **Rolle**: Haupt-Firewall & Router
- **IP-Adressen**:
  - VLAN 10: 10.15.10.99
  - VLAN 40: 10.15.40.99
  - VLAN 70: 10.15.70.99
  - VLAN 100: 10.15.100.99

**Integration:**
- In NixOS Config für Topologie enthalten
- Wireguard Konfiguration
- Firewall-Regeln Referenz

---

## 🌐 Netzwerk-Architektur

### Sicherheitszonen-Konzept

Die Netzwerk-Segmentierung basiert auf den kanadischen IT-Sicherheits-Standards **ITSG-22** und **ITSG-38** (IT Security Guidelines).

#### Zonen-Übersicht

| Zone | VLAN | Subnet | Gateway | Zweck | Zugriff |
|------|------|---------|---------|-------|---------|
| **OZ** (Operations) | 10 | 10.15.10.0/24 | .99 | Vertrauenswürdige Familie-Geräte | Voll |
| **GUEST** | 20 | 10.15.20.0/24 | .99 | Gäste-Geräte | Internet only |
| **SECURITY** | 30 | 10.15.30.0/24 | .99 | MAC-basierte Kontrolle | Internet only |
| **RZ** (Restricted) | 40 | 10.15.40.0/24 | .99 | Primäre Services | Kontrolliert |
| **IoT** | 60 | 10.15.60.0/24 | .99 | IoT-Geräte | Internet only, isoliert |
| **DMZ** | 70 | 10.15.70.0/24 | .99 | Öffentlich-zugängliche Services | Port-spezifisch |
| **MRZ** (Management) | 100 | 10.15.100.0/24 | .99 | Infrastruktur-Management | Hoch eingeschränkt |
| **Proxy VPN** | - | 10.46.0.0/24 | - | Wireguard Tunnel | VPS ↔ Local |

### VLAN 10 - Trust/Operations Zone (OZ)

**Zweck:** Vertrauenswürdige Geräte der Familie

**Hosts:**
- HL-1-OZ-PC-01 (Desktop): 10.15.10.25
- HL-1-MRZ-HOST-02: 10.15.10.254

**Zugriff:**
- Voller Netzwerk-Zugriff
- Zugriff auf alle internen Services
- Internet-Zugriff

**Verwendung:**
- Hauptarbeitsplatz-Computer
- Vertrauenswürdige Laptops/Tablets
- Familien-Geräte

---

### VLAN 20 - Guest

**Zweck:** Gäste-Geräte ohne Vertrauen

**Zugriff:**
- Nur Internet
- Isoliert von anderen VLANs
- Keine Service-Discovery

**Verwendung:**
- Gäste-WiFi
- Unbekannte Geräte
- Temporäre Geräte

---

### VLAN 30 - Security

**Zweck:** MAC-Adress-basierte Zugriffskontrolle

**Zugriff:**
- Nur Internet
- Erweiterte Isolation
- Monitoring

**Verwendung:**
- Potentiell kompromittierte Geräte
- Quarantäne-Zone
- Test-Geräte

---

### VLAN 40 - Servers (RZ - Restricted Zone)

**Zweck:** Primäre Service-Infrastruktur

**Hosts (20+ Services):**

**Storage & Sync:**
- HL-3-RZ-SMB-01 (Samba): 10.15.40.11
- HL-3-RZ-SYNC-01 (Syncthing): 10.15.40.13
- HL-3-RZ-SYNC-02 (Syncthing Ina): 10.15.40.113
- HL-3-RZ-S3-01 (Minio): 10.15.40.19

**Datenbanken:**
- HL-3-RZ-INFLUX-01 (InfluxDB): 10.15.40.12

**Development:**
- HL-3-RZ-GIT-01 (Forgejo): 10.15.40.14
- HL-3-RZ-AFFINE-01 (Affine): 10.15.40.110

**Dokumente:**
- HL-3-RZ-PAPERLESS-01 (Paperless): 10.15.40.16
- HL-3-RZ-ENTE-01 (Ente): 10.15.40.17

**Monitoring:**
- HL-3-RZ-GRAFANA-01 (Grafana): 10.15.40.111
- HL-3-RZ-LOG-01 (Parseable): 10.15.40.18

**Infrastruktur:**
- HL-3-RZ-DNS-01 (AdGuard): 10.15.40.21
- HL-3-RZ-VAULT-01 (Vaultwarden): 10.15.40.22

**Home Automation:**
- HL-3-RZ-HASS-01 (Home Assistant): 10.15.40.36
- HL-3-RZ-MQTT-01 (Mosquitto): 10.15.40.33
- HL-3-RZ-RED-01 (Node-RED): 10.15.40.35
- HL-3-RZ-HOME-01 (Homepage): 10.15.40.37
- HL-3-RZ-POWER-02 (Power Meter): 10.15.40.34

**Weitere:**
- HL-3-RZ-UNIFI-01 (Unifi): 10.15.40.31
- HL-3-RZ-MC-01 (Minecraft): 10.15.40.32
- HL-3-RZ-IBKR-01 (IBKR): 10.15.40.15

**Zugriff:**
- Kontrollierter Zugriff von Trust Zone
- Service-spezifische Firewall-Regeln
- Logging & Monitoring
- Kein direkter Internet-Zugriff

---

### VLAN 60 - IoT

**Zweck:** IoT-Geräte (Internet of Things)

**Geräte:**
- Smart Home Geräte
- IP-Kameras
- Sensoren
- Smart Speakers

**Zugriff:**
- Nur Internet
- Isoliert vom Hauptnetzwerk
- Verbindung zu MQTT Broker (VLAN 40)

---

### VLAN 70 - DMZ

**Zweck:** Öffentlich-zugängliche Services

**Hosts:**
- HL-3-DMZ-PROXY-01 (Caddy): 10.15.70.1
- HL-3-MRZ-FW-01 (Firewall): 10.15.70.99

**Zugriff:**
- Port-spezifischer Zugriff vom Internet
- Eingehende Verbindungen erlaubt (gefiltert)
- Ausgehende Verbindungen zu RZ Services

**Verwendung:**
- Reverse Proxy
- Öffentliche Websites
- API Endpoints

---

### VLAN 100 - Management (MRZ)

**Zweck:** Infrastruktur-Management

**Hosts:**
- HL-1-MRZ-HOST-01: 10.15.100.10
- HL-1-MRZ-HOST-02: 10.15.100.20
- HL-1-MRZ-HOST-03: 10.15.100.30
- HL-1-OZ-PC-01: 10.15.100.25
- HL-3-MRZ-FW-01: 10.15.100.99

**Zugriff:**
- Hoch eingeschränkt
- Nur Admin-Zugriff
- SSH, IPMI, Management-Interfaces
- Keine Internet-Verbindung

**Verwendung:**
- Hypervisor-Management
- Switch-Konfiguration
- Firewall-Administration
- Backup-Operations

---

### Proxy VPN Network

**Zweck:** Wireguard-Tunnel zwischen lokalem Proxy und VPS

**Netzwerk:**
- IPv4: 10.46.0.0/24
- IPv6: fd00:44::/120

**Endpunkte:**
- HL-3-DMZ-PROXY-01 (Local): 10.46.0.1
- HL-4-PAZ-PROXY-01 (VPS): 10.46.0.90

**Funktion:**
- Sicherer Tunnel für eingehenden Traffic
- SSL Termination auf VPS
- Traffic-Weiterleitung zu internen Services
- OAuth2 Authentication

---

### Firewall-Regeln (Konzept)

#### Inter-VLAN Kommunikation

```
Trust (10) → Server (40): Erlaubt (alle Services)
Trust (10) → DMZ (70): Erlaubt (HTTP/HTTPS)
Trust (10) → Management (100): Erlaubt (SSH, Admin)
Trust (10) → Internet: Erlaubt

Guest (20) → Internet: Erlaubt
Guest (20) → *: Blockiert

IoT (60) → Internet: Erlaubt
IoT (60) → Server (40): Nur MQTT (Port 1883)
IoT (60) → *: Blockiert

DMZ (70) → Server (40): Service-spezifisch
DMZ (70) → Internet: Erlaubt
DMZ (70) → *: Blockiert

Server (40) → Internet: Über NAT (selektiv)
Server (40) → *: Blockiert

Management (100) → All: Erlaubt (Admin)
```

#### Wireguard VPN

```
VPS (HL-4-PAZ-PROXY-01) → Local Proxy (HL-3-DMZ-PROXY-01)
Port: 51820/UDP
Encryption: Wireguard (Curve25519)
Routing: 10.46.0.0/24
```

---

### DNS-Struktur

**Primary DNS:**
- AdGuard Home (HL-3-RZ-DNS-01): 10.15.40.21
- Port: 53 (DNS), 853 (DNS-over-TLS)

**Upstream DNS:**
- Cloudflare: 1.1.1.1 / 2606:4700:4700::1111
- Google: 8.8.8.8 / 2001:4860:4860::8888

**Funktionen:**
- Ad-Blocking & Tracking-Protection
- Custom DNS Records für lokale Services
- DNS-over-HTTPS (DoH)
- Query-Logging & Statistics

**Lokale Domains:**
- Intern: `*.czichy.com`
- Services: `service.czichy.com`
- Hosts: `hostname.czichy.com`

---

## 🚀 Services & Anwendungen

### Service-Kategorien

#### 1. Storage & Dateimanagement

##### Samba (HL-3-RZ-SMB-01)
- **Zweck**: Netzwerk-Dateifreigabe
- **Protokoll**: SMB/CIFS
- **Port**: 445
- **Shares**:
  - `bibliothek` - Gemeinsame Dokumentenbibliothek
  - `media` - Videos, Musik, Fotos
  - `dokumente` - Allgemeine Dokumente
  - `users/christian` - Persönlicher Bereich
  - `users/ina` - Persönlicher Bereich
- **Features**:
  - Active Directory Integration (optional)
  - Versionierung
  - Recycle Bin
  - Shadow Copies

##### Syncthing (HL-3-RZ-SYNC-01 & HL-3-RZ-SYNC-02)
- **Zweck**: Dezentralisierte Datei-Synchronisation
- **Web-UI**: Port 8384
- **Sync-Protocol**: BEP (Block Exchange Protocol)
- **Features**:
  - Continuous Sync
  - Versionierung
  - Ignore-Patterns
  - Verschlüsselung
- **Verwendung**:
  - Dokument-Sync zwischen Geräten
  - Foto-Backup
  - Konfiguration-Sync

##### Minio (HL-3-RZ-S3-01)
- **Zweck**: S3-kompatibler Object Storage
- **API**: Port 9000
- **Console**: Port 9001
- **Features**:
  - S3 API kompatibel
  - Bucket-Policies
  - Versioning
  - Lifecycle Management
- **Verwendung**:
  - Backup-Ziel
  - Application Storage
  - Media Archive

---

#### 2. Dokument-Management

##### Paperless-ngx (HL-3-RZ-PAPERLESS-01)
- **Zweck**: Dokumenten-Management & OCR
- **Web-UI**: Port 8000
- **Features**:
  - Automatische OCR (Tesseract)
  - Tagging & Kategorisierung
  - Volltextsuche
  - E-Mail-Import
  - Scan-Integration
- **Workflow**:
  1. Dokument scannen/hochladen
  2. Automatische OCR
  3. Auto-Tagging via ML
  4. Archivierung
- **Storage**: PostgreSQL + Files

##### Ente (HL-3-RZ-ENTE-01)
- **Zweck**: Ende-zu-Ende verschlüsseltes Foto-Backup
- **Features**:
  - E2E Encryption
  - Mobile Apps
  - Sharing
  - Albums
- **Alternative zu**: Google Photos

##### Affine (HL-3-RZ-AFFINE-01)
- **Zweck**: Knowledge Base / Notizen
- **Features**:
  - Markdown Support
  - Block-based Editor
  - Collaboration
  - Self-hosted
- **Alternative zu**: Notion

---

#### 3. Development & Collaboration

##### Forgejo (HL-3-RZ-GIT-01)
- **Zweck**: Self-hosted Git Forge
- **Web-UI**: Port 3000
- **SSH**: Port 222
- **Features**:
  - Git Repository Hosting
  - Pull Requests / Merge Requests
  - Issue Tracking
  - CI/CD (Actions)
  - Packages Registry
  - Wiki
- **Alternative zu**: GitHub, GitLab
- **Integration**:
  - SSH-Keys
  - OAuth2
  - Webhooks

---

#### 4. Monitoring & Observability

##### InfluxDB (HL-3-RZ-INFLUX-01)
- **Zweck**: Time-Series Datenbank
- **Version**: InfluxDB 2.x
- **API**: Port 8086
- **Features**:
  - High-Performance Time-Series DB
  - Flux Query Language
  - Data Retention Policies
  - Downsampling
- **Datenquellen**:
  - Telegraf (System Metrics)
  - Home Assistant
  - Custom Applications
- **Metriken**:
  - System (CPU, RAM, Disk, Network)
  - Services (Response Times, Errors)
  - IoT (Temperature, Power, etc.)

##### Grafana (HL-3-RZ-GRAFANA-01)
- **Zweck**: Metrics Visualization & Dashboards
- **Web-UI**: Port 3000
- **Features**:
  - Multiple Datasources
  - Custom Dashboards
  - Alerting
  - Annotations
  - Plugins
- **Datasources**:
  - InfluxDB (primary)
  - Parseable (logs)
  - JSON API
- **Dashboards**:
  - System Overview
  - Network Traffic
  - Service Health
  - Home Automation
  - Power Consumption

##### Parseable (HL-3-RZ-LOG-01)
- **Zweck**: Log Aggregation & Search
- **API**: Port 8000
- **Features**:
  - High-Performance Log Storage
  - Parquet-based
  - SQL Queries
  - Low Resource Usage
- **Log-Quellen**:
  - Systemd Journals
  - Application Logs
  - Web Server Logs
  - Firewall Logs
- **Alternative zu**: Loki, Elasticsearch

##### Telegraf
- **Zweck**: Metrics Collection Agent
- **Deployment**: Auf allen Hosts
- **Outputs**: InfluxDB
- **Inputs**:
  - system (CPU, RAM, Disk)
  - net (Network Traffic)
  - netstat (Connections)
  - processes (Process Stats)
  - docker (Container Metrics)
  - systemd (Service States)

##### Uptime Kuma
- **Zweck**: Service Monitoring & Status Page
- **Features**:
  - HTTP(S) Monitoring
  - TCP Port Monitoring
  - Ping Monitoring
  - Certificate Expiry
  - Status Page
  - Multi-Channel Notifications

---

#### 5. Infrastruktur-Services

##### AdGuard Home (HL-3-RZ-DNS-01)
- **Zweck**: Network-wide Ad Blocking & DNS
- **Web-UI**: Port 3000
- **DNS**: Port 53
- **Features**:
  - DNS-based Ad Blocking
  - Tracker Blocking
  - Parental Controls
  - Query Logging
  - Statistics
  - Custom DNS Records
- **Blocklists**:
  - AdGuard DNS filter
  - OISD
  - Custom Lists
- **Clients**: ~30+ Geräte

##### Vaultwarden (HL-3-RZ-VAULT-01)
- **Zweck**: Password Manager (Bitwarden-kompatibel)
- **Web-UI**: Port 80
- **API**: Port 80
- **Features**:
  - Password Storage
  - 2FA Support
  - Sharing
  - Organizations
  - Secure Notes
  - File Attachments
- **Clients**:
  - Browser Extensions
  - Mobile Apps
  - Desktop Apps
  - CLI
- **Backup**: Automatisch zu S3

##### Caddy (HL-3-DMZ-PROXY-01)
- **Zweck**: Reverse Proxy (lokal)
- **Config**: Caddyfile
- **Features**:
  - Automatic HTTPS (Internal CA)
  - HTTP/2 & HTTP/3
  - Reverse Proxy
  - Load Balancing
  - File Server
- **Backends**:
  - Alle Services in VLAN 40
- **Zertifikate**:
  - Internal CA (selbst-signiert)
  - Auto-Renewal

##### Caddy (HL-4-PAZ-PROXY-01 - VPS)
- **Zweck**: Reverse Proxy (öffentlich)
- **Features**:
  - Let's Encrypt ACME
  - OAuth2 Middleware
  - Rate Limiting
  - GeoIP Blocking (optional)
- **Backends**:
  - Wireguard → Local Caddy → Services
- **Authentifizierung**:
  - OAuth2 (Google/GitHub)
  - IP Whitelist (optional)

---

#### 6. Home Automation & IoT

##### Home Assistant (HL-3-RZ-HASS-01)
- **Zweck**: Smart Home Hub
- **Web-UI**: Port 8123
- **Features**:
  - 15+ Integration Modules
  - Automations
  - Scenes
  - Scripts
  - Blueprints
- **Integrationen**:
  - **Sensoren**: BME680 (Temperature, Humidity, Pressure, Air Quality)
  - **Bluetooth**: BLE Device Tracking
  - **Android**: Companion App Integration
  - **MQTT**: Device Communication
  - **Network**: Device Presence Detection
- **Custom Automations**:
  - Witze-des-Tages Benachrichtigung
  - Timer & Erinnerungen
  - Wetter-Benachrichtigungen
  - Laptop-Tracking (Arbeit/Zuhause)
  - Lade-Benachrichtigungen (Handy/Laptop)
- **Authentication**: LDAP Integration
- **Dashboard**: Lovelace UI

##### Mosquitto (HL-3-RZ-MQTT-01)
- **Zweck**: MQTT Broker
- **Port**: 1883 (MQTT), 8883 (MQTTS)
- **Features**:
  - Lightweight Messaging
  - QoS Levels
  - Retained Messages
  - Authentication
- **Clients**:
  - Home Assistant
  - ESP32/ESP8266 Devices
  - Node-RED
  - Custom Applications
- **Topics**:
  - `homeassistant/#` - HA Discovery
  - `sensors/#` - Sensor Data
  - `switches/#` - Switch Control
  - `status/#` - Device Status

##### Node-RED (HL-3-RZ-RED-01)
- **Zweck**: Visual Flow-based Automation
- **Web-UI**: Port 1880
- **Features**:
  - Flow-based Programming
  - Visual Editor
  - Function Nodes (JavaScript)
  - 1000+ Community Nodes
- **Verwendung**:
  - Complex Automations
  - Data Transformation
  - API Integration
  - Debugging

##### Homepage (HL-3-RZ-HOME-01)
- **Zweck**: Service Dashboard
- **Features**:
  - Service Status
  - Quick Links
  - Widgets (Weather, Calendar, etc.)
  - Customizable Layout
- **Alternative zu**: Heimdall, Organizr

##### Power Meter (HL-3-RZ-POWER-02)
- **Zweck**: Energy Monitoring
- **Features**:
  - Real-time Power Consumption
  - Historical Data
  - Cost Calculation
  - Export to InfluxDB
- **Hardware**: Custom ESP32-based

---

#### 7. Netzwerk & Management

##### Unifi Controller (HL-3-RZ-UNIFI-01)
- **Zweck**: Unifi Network Management
- **Web-UI**: Port 8443
- **Features**:
  - AP Management
  - Network Topology
  - Client Management
  - Statistics
  - Firewall Rules
- **Devices**:
  - Unifi Access Points
  - Unifi Switches (optional)

---

#### 8. Weitere Services

##### Minecraft Server (HL-3-RZ-MC-01)
- **Zweck**: Gaming Server
- **Port**: 25565
- **Version**: (konfigurierbar)
- **Features**:
  - Automated Backups
  - World Management
  - Plugin Support (Paper/Spigot)

##### IBKR Flex Downloader (HL-3-RZ-IBKR-01)
- **Zweck**: Interactive Brokers Daten-Download
- **Features**:
  - Automatischer Flex Query Download
  - Portfolio Data
  - Trade History
  - Export zu CSV/JSON
- **Schedule**: Täglich

---

### Desktop-Anwendungen (HL-1-OZ-PC-01)

#### Window Manager / Desktop

**Niri (Primary)**
- Wayland Scrollable Tiling Compositor
- Horizontales Scrolling
- Minimalistisch
- Touch-friendly

**Hyprland (Available)**
- Dynamic Tiling Wayland Compositor
- Animationen
- Gaps & Borders
- Extensive Configuration

#### Terminals
- **Foot** (Default): Wayland-native, lightweight
- **Alacritty**: GPU-accelerated
- **Ghostty**: Modern, feature-rich
- **Kitty**: GPU-accelerated, extensible

#### Editoren
- **Helix** (Default): Modal editor, Rust-based
- **Zed**: Collaborative, fast
- **Neovim**: Classic, extensible

#### Shells
- **Nushell** (Default): Structured data pipelines
- **Fish**: User-friendly
- **Zsh**: Powerful, customizable

#### Browser
- **Zen Browser** (Default): Firefox-based, privacy-focused
- **Firefox**: With Arkenfox hardening
- **Chromium**: Google Chrome open-source
- **Vivaldi**: Feature-rich

#### File Manager
- **Yazi** (Default): Terminal-based, fast
- **lf**: Lightweight file manager
- **Thunar**: Graphical, Xfce-based

#### Development
- **Direnv**: Environment management
- **Git**: Version control
- **Jujutsu**: Alternative VCS
- **GPG**: Encryption
- **Docker/Podman**: Containers
- **Interactive Brokers TWS**: Trading platform

#### Utilities
- **Walker**: Application Launcher
- **Wofi**: Launcher alternative
- **btop**: System Monitor
- **tmux/zellij**: Terminal Multiplexer
- **Starship**: Shell Prompt
- **Fastfetch**: System Info
- **Bitwarden**: Password Manager
- **Wine**: Windows Compatibility

#### Gaming
- **Steam**: Game Platform
- **Minecraft**: Game

---

## 📦 Module & Konfiguration

### NixOS Module-System

#### Profil-Hierarchie

```
base (Basis für alle)
├── minimal (Minimal-System)
├── headless (Server ohne GUI)
├── server (Server mit Services)
└── graphical (Desktop)
    ├── graphical-plasma6
    ├── graphical-hyprland
    └── graphical-niri
```

#### Profile im Detail

**modules/nixos/profiles/base.nix:**
- Core System Configuration
- Basic Networking
- SSH
- Users
- Nix Settings
- Standard Tools

**modules/nixos/profiles/server.nix:**
- Server-optimiert
- Keine GUI
- Headless Tools
- Service-Management
- Monitoring Agents

**modules/nixos/profiles/graphical-niri.nix:**
- Niri Window Manager
- Wayland Environment
- Audio (Pipewire)
- Desktop Applications
- Fonts & Themes

---

### Modul-Struktur

#### NixOS Module (`modules/nixos/`)

**services/**
- **networking/**: ssh, wireguard, caddy, nginx, nftables, acme, networkd, networkmanager
- **virtualisation/**: microvm, docker, podman
- **monitoring/**: healthchecks, uptime-kuma, telegraf
- **desktop/**: flatpak, greetd, printing
- **automation/**: home-assistant (15+ sub-modules)
- **backup/**: restic
- **notification/**: ntfy-sh
- **sync/**: syncthing

**system/**
- **users/**: czichy, root, builder
- **impermanence**: Ephemeral root configuration
- **initrd-ssh**: Remote LUKS unlock
- **zfs**: ZFS pool management
- **disko**: Declarative disk partitioning

**tasks/**
- **garbage-collection**: Automatic Nix store cleanup
- **auto-upgrade**: System updates

**programs/**
- **thunar**: File manager
- **wayland/**: ags, anyrun, waybar

---

#### Home-Manager Module (`modules/home-manager/`)

**profiles/**
- base, minimal, server, headless
- graphical, graphical-hyprland, graphical-niri, graphical-plasma

**programs/**
- **browsers/**: zen, firefox, chromium, vivaldi
- **editors/**: helix, zed, neovim
- **terminals/**: foot, alacritty, ghostty, kitty
- **shells/**: nushell, fish, zsh
- **file-managers/**: yazi, lf, thunar
- **games/**: steam, minecraft

**desktop/**
- **window-managers/**: hyprland, niri
- **wayland/**: swaync, waybar, walker

**services/**
- swaync, dunst, keepassxc, redshift, picom

**hardware/**
- monitors, nixGL

**system/**
- impermanence (user data)

---

### Flake Inputs (40+ Dependencies)

#### Core
- **nixpkgs** (unstable)
- **home-manager**
- **disko** (disk management)
- **flake-parts** (modular flakes)

#### Security
- **agenix** (secrets management)
- **private** (private secrets repo)
- **nixos-nftables-firewall**

#### Virtualization
- **microvm** (lightweight VMs)

#### Utilities
- **nur** (Nix User Repository)
- **nixGL** (OpenGL wrapper)
- **hardware** (nixos-hardware)
- **nix-topology** (network visualization)
- **impermanence**

#### Development
- **devenv** (development environments)
- **treefmt-nix** (code formatting)
- **git-hooks** (pre-commit hooks)
- **nix-inspect** (debugging)

#### Packages
- **ghostty** (terminal)
- **helix** (editor)
- **walker** (launcher)
- **zen-browser** (browser)
- **niri** (window manager)
- **firefox-addons**
- **nix-flatpak**
- **nix-minecraft**

#### Services
- **docspell** (document management)
- **ibkr-rust** (Interactive Brokers)
- **power-meter** (custom)

---

### Extended Library

Custom helper functions in `parts/lib/`:

**Networking:**
- `mkNetwork`: Network definition helper
- `mkHost`: Host IP assignment
- `mkVLAN`: VLAN configuration
- `getHostIP`: IP lookup by hostname

**Systemd:**
- `mkService`: Service definition
- `mkTimer`: Timer configuration
- `mkMount`: Mount unit

**Firewall:**
- `mkNftRule`: nftables rule builder
- `mkZone`: Security zone definition
- `mkForward`: Traffic forwarding

**Disko:**
- `mkZFSPool`: ZFS pool configuration
- `mkDataset`: Dataset definition
- `mkPartition`: Partition helper

**Backup:**
- `mkResticJob`: Backup job definition
- `mkResticRepo`: Repository configuration

**CI/CD:**
- `mkCheck`: CI check definition
- `mkDeployment`: Deployment configuration

---

## 🔐 Besondere Features

### 1. MicroVM Orchestration

**Technologie:** microvm.nix

**Features:**
- Lightweight VMs (ohne QEMU overhead)
- ZFS-basierte Storage
- Macvtap Networking
- Shared Folders
- Journal Integration

**Konfiguration:**

```nix
microvm.guests = {
  "HL-3-RZ-SMB-01" = {
    # Auto-generated MAC address
    macAddress = "02:00:00:00:00:0b";
    
    # ZFS dataset automatically created
    zfsDataset = "rpool/safe/guests/samba";
    
    # Network bridge to VLAN 40
    interface = "mv-samba";
    bridge = "br40";
    
    # Shared folders
    shares = [{
      source = "/storage/shares";
      target = "/mnt/shares";
    }];
    
    # Guest system configuration
    config = ./guests/samba.nix;
  };
};
```

**Vorteile:**
- Minimaler Overhead
- Schneller Start
- Isolation
- Deklarative Konfiguration

---

### 2. ZFS Storage Management

**Pools:**
- **rpool**: System & Guest Storage
- **storage**: Data Storage

**Dataset-Struktur:**

```
rpool/
├── local/              # Ephemeral (nicht-persistent)
│   ├── root           # System root (wiped on boot)
│   └── nix            # Nix store (persistent aber cacheable)
├── safe/               # Persistent data
│   ├── home           # User home directories
│   ├── persist        # System persistence (/etc, /var)
│   └── guests/        # VM-specific datasets
│       ├── samba/
│       ├── forgejo/
│       └── ...
└── bunker/             # Long-term storage
    └── backups        # Backup datasets

storage/
├── shares/            # Samba shares
│   ├── bibliothek/
│   ├── media/
│   ├── dokumente/
│   └── users/
└── data/              # Application data
```

**Features:**
- Compression (lz4)
- Snapshots (automatisch)
- Encryption (per-dataset)
- Deduplication (optional)
- Scrubbing (wöchentlich)

**Snapshot-Strategie:**
```
Frequent: 15min für 1h
Hourly: 1h für 1d
Daily: 1d für 1w
Weekly: 1w für 1m
Monthly: 1m für 1y
```

---

### 3. Impermanence (Ephemeral Root)

**Konzept:**
- Root-Filesystem wird bei jedem Boot gelöscht
- Nur explizit deklarierte Pfade bleiben persistent
- Erzwingt deklarative Konfiguration

**Persistent-Verzeichnisse:**

```nix
environment.persistence."/persist" = {
  directories = [
    "/etc/nixos"           # NixOS config
    "/etc/NetworkManager"  # Network connections
    "/var/log"             # Logs
    "/var/lib/systemd"     # Systemd state
    "/var/lib/docker"      # Docker data
  ];
  
  files = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
  ];
};
```

**Home-Manager Persistence:**

```nix
home.persistence."/persist/home/czichy" = {
  directories = [
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Videos"
    ".config"              # Config files
    ".local/share"         # Application data
    ".ssh"                 # SSH keys
  ];
  
  files = [
    ".bash_history"
    ".zsh_history"
  ];
};
```

**Vorteile:**
- Sauberer System-State
- Keine Cruft-Akkumulation
- Erzwingt Reproduzierbarkeit
- Einfaches Rollback (neuer Boot)

---

### 4. Secrets Management mit agenix

**Architektur:**
- Secrets verschlüsselt in Git
- Pro Host-Key verschlüsselt
- SSH-basierte Entschlüsselung

**Secrets-Struktur:**

```
private/ (separate repo)
├── secrets/
│   ├── wireguard/
│   │   ├── host-01-private.age
│   │   └── vps-private.age
│   ├── passwords/
│   │   ├── user-czichy.age
│   │   └── admin-root.age
│   ├── certificates/
│   │   ├── ca-cert.age
│   │   └── ca-key.age
│   └── api-keys/
│       ├── cloudflare.age
│       └── github.age
└── secrets.nix
```

**Verwendung:**

```nix
# In host configuration
age.secrets.wireguard-private = {
  file = ../../private/secrets/wireguard/host-01-private.age;
  owner = "systemd-network";
  group = "systemd-network";
};

# In service
services.wireguard.interfaces.wg0 = {
  privateKeyFile = config.age.secrets.wireguard-private.path;
};
```

**Rekey-Prozess:**

```bash
# Add new host key
cd private
agenix --rekey \
  --identity /etc/ssh/ssh_host_ed25519_key \
  --recipients hosts/new-host/keys.txt

# Update all secrets
agenix --rekey-all
```

---

### 5. Internal CA & Certificate Management

**Struktur:**

```
Internal CA (Self-Signed)
├── CA Certificate (ca-cert.pem)
├── CA Key (ca-key.pem)
└── Service Certificates
    ├── *.czichy.com (Wildcard)
    ├── caddy.czichy.com
    └── grafana.czichy.com
```

**Caddy Internal PKI:**

```nix
services.caddy = {
  globalConfig = ''
    pki {
      ca internal {
        name "czichy.com Internal CA"
      }
    }
  '';
  
  virtualHosts."grafana.czichy.com" = {
    extraConfig = ''
      tls internal
      reverse_proxy http://10.15.40.111:3000
    '';
  };
};
```

**System Trust Store:**

```nix
security.pki.certificates = [
  (builtins.readFile ../../assets/certs/ca-cert.pem)
];
```

**Vorteile:**
- Keine Browser-Warnungen
- Volle Kontrolle
- Offline verfügbar
- Keine Rate Limits

---

### 6. Wireguard VPN Architecture

**Topologie:**

```
Internet
   ↓
VPS (HL-4-PAZ-PROXY-01)
   ↓ Wireguard
Local Proxy (HL-3-DMZ-PROXY-01)
   ↓ Reverse Proxy
Internal Services (VLAN 40)
```

**VPS Config (HL-4-PAZ-PROXY-01):**

```nix
networking.wireguard.interfaces.wg0 = {
  ips = [ "10.46.0.90/24" "fd00:44::90/120" ];
  listenPort = 51820;
  privateKeyFile = config.age.secrets.wireguard-vps-private.path;
  
  peers = [{
    # Local Proxy
    publicKey = "...";
    allowedIPs = [ "10.46.0.1/32" "10.15.40.0/24" ];
    persistentKeepalive = 25;
  }];
};
```

**Local Proxy Config (HL-3-DMZ-PROXY-01):**

```nix
networking.wireguard.interfaces.wg0 = {
  ips = [ "10.46.0.1/24" "fd00:44::1/120" ];
  privateKeyFile = config.age.secrets.wireguard-local-private.path;
  
  peers = [{
    # VPS
    publicKey = "...";
    endpoint = "vps.example.com:51820";
    allowedIPs = [ "10.46.0.90/32" ];
    persistentKeepalive = 25;
  }];
};
```

**Traffic Flow:**

1. Internet Request → VPS:443 (HTTPS)
2. VPS Caddy → Wireguard Tunnel → Local Proxy
3. Local Proxy Caddy → Service (VLAN 40)
4. Response zurück durch Tunnel

---

### 7. OAuth2 Authentication (VPS)

**Caddy OAuth2 Middleware:**

```
https://service.example.com
   ↓
OAuth2 Check
   ├─→ Not Authenticated → Google OAuth2 Login
   └─→ Authenticated → Forward to Backend
```

**Konfiguration:**

```nix
services.caddy.extraConfig = ''
  oauth2 {
    provider google
    client_id {env.OAUTH_CLIENT_ID}
    client_secret {env.OAUTH_CLIENT_SECRET}
    allowed_emails czichy@example.com
  }
  
  https://grafana.example.com {
    oauth2
    reverse_proxy http://10.46.0.1:3001
  }
'';
```

**Geschützte Services:**
- Grafana
- Paperless
- Home Assistant (optional)
- Homepage Dashboard

---

### 8. Network Topology Visualization

**Tool:** nix-topology

**Features:**
- Automatische Diagramm-Generierung
- Hosts, Networks, Services
- SVG Output
- Interaktiv

**Konfiguration:**

```nix
topology = {
  nodes = {
    # Automatically discovered from nixosConfigurations
  };
  
  networks = {
    vlan10 = {
      name = "Trust Zone";
      cidrv4 = "10.15.10.0/24";
    };
    # ... weitere VLANs
  };
};
```

**Generierung:**

```bash
nix build .#topology
xdg-open result/network-topology.svg
```

---

### 9. Monitoring Stack

**Architektur:**

```
Services/Hosts
   ↓ Telegraf
InfluxDB (Time-Series)
   ↓
Grafana (Visualization)

Logs
   ↓ Systemd Journal / Files
Parseable (Log Storage)
   ↓
Grafana (Log Viewer)
```

**Metriken:**
- System: CPU, RAM, Disk, Network, Temperature
- Services: Status, Response Time, Errors
- Network: Bandwidth, Connections, DNS Queries
- IoT: Sensors, Power, Environment
- Custom: Application-specific

**Dashboards:**
1. **System Overview**: Alle Hosts, Gesamt-Status
2. **Host Details**: Per-Host Metriken
3. **Network**: Traffic, DNS, Firewall
4. **Services**: Service-Status, Response Times
5. **Home Automation**: IoT Devices, Sensors
6. **Power**: Energy Consumption, Costs

---

### 10. Backup Strategy

**Tools:**
- ZFS Snapshots (lokal)
- Restic (remote)
- rsync (sync)

**Snapshot-Schedule:**

```nix
services.zfs.autoSnapshot = {
  enable = true;
  frequent = 4;   # 15min für 1h
  hourly = 24;    # 1h für 1d
  daily = 7;      # 1d für 1w
  weekly = 4;     # 1w für 1m
  monthly = 12;   # 1m für 1y
};
```

**Restic Jobs:**

```nix
services.restic.backups = {
  daily-to-s3 = {
    repository = "s3:backup.example.com:backups";
    passwordFile = config.age.secrets.restic-password.path;
    
    paths = [
      "/persist"
      "/home"
      "/storage/shares"
    ];
    
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
    ];
  };
};
```

**Backup-Ziele:**
1. Lokal: ZFS Snapshots (rpool/safe)
2. Netzwerk: Minio S3 (HL-3-RZ-S3-01)
3. Remote: Cloud S3 / Backblaze B2

---

## 🔧 Installation & Deployment

### Initiale Installation

#### 1. ISO Vorbereitung

**Custom Installer ISO mit SSH:**

```bash
cd installer/
nix build .#nixosConfigurations.installer.config.system.build.isoImage
```

**Oder mit Nix Generators:**

```bash
cd ISO/
nix run github:nix-community/nixos-generators -- \
  --flake .#sshInstallIso \
  --format iso
```

**ISO Features:**
- SSH Server aktiviert
- SSH Public Key embedded
- ZFS Support
- Netzwerk-Tools

#### 2. Boot & SSH

```bash
# ISO auf USB schreiben
dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress

# Nach Boot via SSH verbinden
ssh nixos@<ip-address>

# Root werden
sudo su
```

#### 3. Host festlegen

```bash
export HOST=HL-1-MRZ-HOST-01
```

#### 4. SSH Keys für Secrets

**Installer Key:**

```bash
ssh-keygen -t ed25519 \
  -f /root/.ssh/id_ed25519 \
  -C "root@installer"

cat /root/.ssh/id_ed25519.pub
# → In GitHub als Deploy Key hinzufügen
```

#### 5. Repository klonen

```bash
git clone git@github.com:czichy/nixos.git
cd nixos
```

#### 6. Disk Konfiguration

**Disko-Datei anpassen:**

```bash
# Disk Device identifizieren
lsblk

# In hosts/${HOST}/disko.nix anpassen
vim hosts/${HOST}/disko.nix
```

#### 7. Disk Partitionierung

```bash
sudo nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode disko \
  --flake .#"${HOST}"
```

**Verifizieren:**

```bash
lsblk --output "NAME,SIZE,FSTYPE,FSVER,LABEL,PARTLABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS,DISC-MAX"
```

#### 8. SSH Host Keys generieren

**Initrd SSH (für LUKS unlock):**

```bash
mkdir -p /mnt/nix/secret/initrd
ssh-keygen -t ed25519 \
  -N "" \
  -C "initrd@${HOST}" \
  -f /mnt/nix/secret/initrd/ssh_host_ed25519_key
```

**System SSH:**

```bash
mkdir -p /mnt/persist/etc/ssh/
ssh-keygen -t ed25519 \
  -N "" \
  -C "${HOST}" \
  -f /mnt/persist/etc/ssh/ssh_host_ed25519_key

# Key für Secrets benötigt
cat /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
# → In private repo zu hosts/${HOST}/keys.txt hinzufügen
```

#### 9. Secrets Rekey

```bash
cd ../private  # Private secrets repo
agenix --rekey --identity /mnt/persist/etc/ssh/ssh_host_ed25519_key
cd ../nixos

# Flake aktualisieren
nix flake lock --update-input private
```

#### 10. NixOS Installation

```bash
sudo nixos-install \
  --root /mnt \
  --flake .#"${HOST}" \
  --show-trace \
  --verbose \
  --impure \
  --no-root-passwd
```

#### 11. Konfiguration verschieben

```bash
mv /root/nixos /mnt/persist/etc/
```

#### 12. System betreten (optional)

```bash
nixos-enter --root /mnt
# Benutzer erstellen, Passwort setzen, etc.
exit
```

#### 13. Unmount & Reboot

```bash
umount -Rl /mnt
zpool export -a
reboot
```

---

### Post-Installation

#### 1. System-Update

```bash
cd /persist/etc/nixos
nix flake update
sudo nixos-rebuild switch --flake .#${HOST}
```

#### 2. Home-Manager aktivieren

```bash
home-manager switch --flake .#czichy@${HOST}
```

#### 3. Secrets überprüfen

```bash
sudo agenix -l
```

#### 4. Services überprüfen

```bash
systemctl status
systemctl --failed
journalctl -xe
```

---

### Remote Deployment

**Von lokalem Rechner:**

```bash
nixos-rebuild switch \
  --flake .#HL-1-MRZ-HOST-01 \
  --target-host root@10.15.100.10 \
  --build-host localhost \
  --verbose
```

**Oder mit deploy-rs (empfohlen):**

```bash
nix run .#deploy -- \
  --targets .#HL-1-MRZ-HOST-01 \
  --dry-activate  # Erst testen

nix run .#deploy -- \
  --targets .#HL-1-MRZ-HOST-01  # Aktivieren
```

---

### MicroVM Guest hinzufügen

**1. Guest-Konfiguration erstellen:**

```nix
# hosts/HL-1-MRZ-HOST-01/guests/neue-vm.nix
{ config, lib, pkgs, ... }: {
  imports = [ ../../../modules/nixos/profiles/minimal.nix ];
  
  networking.hostName = "HL-3-RZ-NEUE-01";
  
  # Service-spezifische Config
  services.myService.enable = true;
  
  system.stateVersion = "25.05";
}
```

**2. Guest zu Host hinzufügen:**

```nix
# hosts/HL-1-MRZ-HOST-01/default.nix
services.microvm.guests = {
  "HL-3-RZ-NEUE-01" = {
    enable = true;
    
    # Network
    network = {
      vlan = "vlan40";
      ip = "10.15.40.50";
    };
    
    # Storage
    zfsDataset = "rpool/safe/guests/neue-vm";
    
    # Config
    config = ./guests/neue-vm.nix;
  };
};
```

**3. Deployen:**

```bash
sudo nixos-rebuild switch --flake .#HL-1-MRZ-HOST-01
```

**4. Guest starten:**

```bash
sudo systemctl start microvm@HL-3-RZ-NEUE-01
sudo systemctl enable microvm@HL-3-RZ-NEUE-01
```

**5. Guest-Journal ansehen:**

```bash
sudo journalctl -u microvm@HL-3-RZ-NEUE-01 -f
```

---

## 🔒 Sicherheit

### Sicherheits-Features

#### 1. Verschlüsselung

**Disk Encryption:**
- LUKS für Root-Partition
- ZFS Native Encryption (optional)
- Remote Unlock via SSH (initrd-ssh)

**Network Encryption:**
- Wireguard für VPN
- TLS für alle Web-Services
- SSH für Admin-Zugriff

**Secrets:**
- agenix für verschlüsselte Secrets
- SSH-Key-basierte Entschlüsselung
- Keine Plaintext-Secrets in Git

#### 2. Firewall & Isolation

**nftables Firewall:**
- Zone-basiert (ITSG-22/ITSG-38)
- Default Deny
- Explizite Allow-Regeln
- Per-Service-Regeln

**Network Isolation:**
- VLAN Segmentierung
- Inter-VLAN Firewall
- IoT-Isolation
- Guest-Isolation

**Container Isolation:**
- MicroVMs statt Container
- Separate Kernel pro VM
- cgroups v2
- Namespace Isolation

#### 3. Access Control

**SSH:**
- Key-basiert (keine Passwörter)
- ed25519 Keys
- Per-User authorized_keys
- Fail2ban (optional)

**Services:**
- OAuth2 für öffentliche Services
- Internal CA für TLS
- LDAP für zentrale Auth (optional)

**Sudo:**
- Minimale sudo-Rechte
- Logging aller sudo-Commands
- Password erforderlich

#### 4. Updates & Patches

**System:**
- NixOS unstable (aktuelle Packages)
- Automatische Updates (optional)
- Rollback bei Problemen

**Services:**
- In MicroVMs isoliert
- Schnelles Update per VM-Rebuild
- Canary-Deployments möglich

#### 5. Monitoring & Alerting

**Security Monitoring:**
- Firewall-Log-Analysis
- Failed Login Attempts
- Anomaly Detection (basic)

**Alerting:**
- Service Down Alerts
- Certificate Expiry
- Disk Space
- Backup Failures

---

### Härtungs-Maßnahmen

#### System-Hardening

```nix
security = {
  # Sudo
  sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };
  
  # Polkit
  polkit.enable = true;
  
  # AppArmor (optional)
  apparmor.enable = true;
  
  # Audit
  audit.enable = true;
  auditd.enable = true;
};

# Kernel Hardening
boot.kernel.sysctl = {
  # Network
  "net.ipv4.ip_forward" = 1;
  "net.ipv4.conf.all.rp_filter" = 1;
  "net.ipv4.tcp_syncookies" = 1;
  
  # Disable ICMP redirects
  "net.ipv4.conf.all.accept_redirects" = 0;
  "net.ipv6.conf.all.accept_redirects" = 0;
  
  # Disable source routing
  "net.ipv4.conf.all.accept_source_route" = 0;
  "net.ipv6.conf.all.accept_source_route" = 0;
};
```

#### Service-Hardening

```nix
systemd.services.myservice = {
  serviceConfig = {
    # User isolation
    DynamicUser = true;
    User = "myservice";
    Group = "myservice";
    
    # Filesystem isolation
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    
    # Network
    PrivateNetwork = false;  # If needed
    
    # Capabilities
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    
    # Namespaces
    PrivateUsers = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    
    # System calls
    SystemCallFilter = "@system-service";
    SystemCallErrorNumber = "EPERM";
  };
};
```

---

### Best Practices

1. **Secrets Management:**
   - Niemals Secrets in Git committen
   - Immer agenix für Secrets verwenden
   - Regelmäßig Keys rotieren

2. **Updates:**
   - Regelmäßig `nix flake update` ausführen
   - Vor Deployment in VM testen
   - Backups vor größeren Updates

3. **Monitoring:**
   - Alerts für kritische Services einrichten
   - Logs regelmäßig überprüfen
   - Firewall-Logs analysieren

4. **Backup:**
   - 3-2-1 Regel (3 Kopien, 2 Medien, 1 offsite)
   - Regelmäßig Restores testen
   - Verschlüsselte Backups

5. **Network:**
   - Least Privilege Prinzip
   - Alle Firewall-Regeln dokumentieren
   - Regelmäßig Netzwerk-Scan (nmap)

6. **Access:**
   - SSH Keys regelmäßig rotieren
   - Separate Keys für verschiedene Zwecke
   - 2FA wo möglich

---

## 💾 Backup & Recovery

### Backup-Strategie

#### Stufe 1: ZFS Snapshots (Lokal)

**Automatische Snapshots:**

```nix
services.zfs.autoSnapshot = {
  enable = true;
  flags = "-k -p --utc";
  
  frequent = 4;   # Alle 15min, behalte 4 (= 1h)
  hourly = 24;    # Jede Stunde, behalte 24 (= 1d)
  daily = 7;      # Jeden Tag, behalte 7 (= 1w)
  weekly = 4;     # Jede Woche, behalte 4 (= 1m)
  monthly = 12;   # Jeden Monat, behalte 12 (= 1y)
};
```

**Manuelle Snapshots:**

```bash
# Snapshot erstellen
sudo zfs snapshot rpool/safe@manual-$(date +%Y%m%d-%H%M%S)

# Snapshots auflisten
sudo zfs list -t snapshot

# Snapshot wiederherstellen
sudo zfs rollback rpool/safe@snapshot-name

# Snapshot löschen
sudo zfs destroy rpool/safe@snapshot-name
```

**Snapshot Management:**

```bash
# Alte Snapshots bereinigen
sudo zfs-auto-snapshot --destroy-only

# Snapshot send/receive (zu anderem Pool)
sudo zfs send rpool/safe@snapshot | \
  sudo zfs receive backup-pool/safe
```

---

#### Stufe 2: Restic (Remote)

**Backup-Jobs:**

```nix
services.restic.backups = {
  # Tägliches Backup zu S3
  daily = {
    repository = "s3:s3.amazonaws.com/my-backups";
    passwordFile = config.age.secrets.restic-password.path;
    
    environmentFile = config.age.secrets.restic-s3-env.path;
    # Enthält: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    
    paths = [
      "/persist/etc"
      "/persist/home"
      "/storage/shares"
    ];
    
    exclude = [
      "*.tmp"
      "*.cache"
      "/persist/home/*/Downloads"
      "/storage/shares/media/cache"
    ];
    
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 12"
      "--keep-yearly 2"
    ];
    
    # Pre/Post hooks
    backupPrepareCommand = ''
      echo "Starting backup at $(date)"
    '';
    
    backupCleanupCommand = ''
      echo "Backup finished at $(date)"
    '';
  };
  
  # Wöchentliches Backup zu lokalem Minio
  weekly-local = {
    repository = "s3:http://10.15.40.19:9000/backups";
    passwordFile = config.age.secrets.restic-password.path;
    
    environmentFile = config.age.secrets.restic-minio-env.path;
    
    paths = [
      "/persist"
      "/storage/shares/dokumente"
    ];
    
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    
    pruneOpts = [
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
};
```

**Manuelle Restic-Operationen:**

```bash
# Repository initialisieren
restic -r s3:... init

# Backup erstellen
restic -r s3:... backup /path/to/data

# Backups auflisten
restic -r s3:... snapshots

# Dateien suchen
restic -r s3:... find filename

# Backup wiederherstellen
restic -r s3:... restore latest --target /restore/path

# Bestimmte Datei wiederherstellen
restic -r s3:... restore latest \
  --target /restore/path \
  --include /path/to/file

# Repository überprüfen
restic -r s3:... check

# Alte Snapshots löschen (entsprechend Prune-Regeln)
restic -r s3:... forget --prune --keep-daily 7

# Repository-Statistiken
restic -r s3:... stats
```

---

#### Stufe 3: Offsite Sync

**Rsync zu Offsite-Backup:**

```nix
systemd.services.offsite-sync = {
  description = "Sync to offsite backup";
  
  script = ''
    ${pkgs.rsync}/bin/rsync -avz --delete \
      -e "ssh -i /root/.ssh/backup_key" \
      /storage/shares/ \
      backup@offsite.example.com:/backups/shares/
  '';
  
  serviceConfig = {
    Type = "oneshot";
    User = "root";
  };
};

systemd.timers.offsite-sync = {
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnCalendar = "weekly";
    Persistent = true;
  };
};
```

---

### Recovery-Szenarien

#### Szenario 1: Einzelne Datei wiederherstellen

**Von ZFS Snapshot:**

```bash
# Snapshot mounten (read-only)
sudo mkdir /mnt/snapshot
sudo mount -t zfs rpool/safe/home@autosnap_2024-01-13_12:00:00 /mnt/snapshot

# Datei kopieren
cp /mnt/snapshot/czichy/Documents/file.txt ~/Documents/

# Unmount
sudo umount /mnt/snapshot
```

**Von Restic:**

```bash
# Datei suchen
restic -r s3:... find file.txt

# Datei wiederherstellen
restic -r s3:... restore latest \
  --target /tmp/restore \
  --include /home/czichy/Documents/file.txt

# Datei zurückkopieren
cp /tmp/restore/home/czichy/Documents/file.txt ~/Documents/
```

---

#### Szenario 2: Komplettes System wiederherstellen

**1. Boot von Installer ISO**

```bash
# ISO booten
# SSH verbinden
ssh nixos@<ip>
sudo su
```

**2. Disk-Layout wiederherstellen**

```bash
cd /mnt/nixos  # Geklontes Repo
export HOST=HL-1-MRZ-HOST-01

# Disko ausführen (erstellt Partitionen)
nix run github:nix-community/disko/latest -- \
  --mode disko \
  --flake .#${HOST}
```

**3. ZFS-Daten wiederherstellen**

**Option A: Von lokalen Snapshots (anderer Disk)**

```bash
# Alten Pool importieren (read-only)
zpool import -o readonly=on old-rpool

# Snapshot senden → neuer Pool
zfs send old-rpool/safe@latest | \
  zfs receive -F rpool/safe
```

**Option B: Von Restic Backup**

```bash
# Restic Repository mounten
mkdir /mnt/restic
restic -r s3:... mount /mnt/restic &

# Daten kopieren
rsync -av /mnt/restic/latest/persist/ /mnt/persist/
rsync -av /mnt/restic/latest/home/ /mnt/persist/home/

# Unmount
fusermount -u /mnt/restic
```

**4. SSH Keys wiederherstellen**

```bash
# Keys sollten in /mnt/persist/etc/ssh sein
ls -la /mnt/persist/etc/ssh/
```

**5. NixOS installieren**

```bash
nixos-install --root /mnt --flake .#${HOST}
```

**6. Reboot**

```bash
umount -Rl /mnt
zpool export -a
reboot
```

---

#### Szenario 3: MicroVM wiederherstellen

**1. VM stoppen**

```bash
sudo systemctl stop microvm@HL-3-RZ-SAMBA-01
```

**2. Dataset wiederherstellen**

```bash
# Von Snapshot
sudo zfs rollback rpool/safe/guests/samba@autosnap_2024-01-13

# Oder von Backup
sudo zfs destroy rpool/safe/guests/samba
restic -r s3:... restore latest \
  --target /tmp/restore \
  --include /guests/samba
sudo zfs create rpool/safe/guests/samba
sudo rsync -av /tmp/restore/guests/samba/ \
  /rpool/safe/guests/samba/
```

**3. VM starten**

```bash
sudo systemctl start microvm@HL-3-RZ-SAMBA-01
```

---

### Backup-Monitoring

**Healthchecks Integration:**

```nix
services.restic.backups.daily = {
  # ... andere Config
  
  backupCleanupCommand = ''
    # Erfolg an Healthchecks melden
    ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 \
      https://hc-ping.com/your-uuid-here
  '';
};
```

**Grafana Dashboard:**
- Letzter erfolgreicher Backup
- Backup-Größe
- Backup-Dauer
- Fehlerrate

**Alerts:**
- Backup failed
- Backup überfällig (>25h)
- Repository-Fehler
- Disk Space niedrig

---

### Backup-Testing

**Regelmäßige Restore-Tests (monatlich):**

```bash
#!/usr/bin/env bash
# test-restore.sh

# Zufällige Datei auswählen
FILE=$(restic -r s3:... ls latest | shuf -n1)

# Wiederherstellen
restic -r s3:... restore latest \
  --target /tmp/restore-test \
  --include "$FILE"

# Verifizieren
if [ -f "/tmp/restore-test$FILE" ]; then
  echo "✅ Restore successful: $FILE"
else
  echo "❌ Restore failed: $FILE"
  exit 1
fi

# Cleanup
rm -rf /tmp/restore-test
```

---

## 🛠️ Wartung & Betrieb

### Regelmäßige Wartung

#### Tägliche Tasks

**Automatisch:**
- ZFS Scrub (wöchentlich)
- Restic Backup (täglich)
- Log Rotation
- Monitoring

**Manuell (bei Bedarf):**
- Log-Review (`journalctl -xe`)
- Service-Status (`systemctl --failed`)

#### Wöchentliche Tasks

1. **System-Updates prüfen:**

```bash
cd /persist/etc/nixos
nix flake update
git diff flake.lock  # Änderungen reviewen
```

2. **Backups verifizieren:**

```bash
# Restic Check
restic -r s3:... check

# ZFS Snapshots
zfs list -t snapshot | tail -20
```

3. **Disk Space prüfen:**

```bash
# ZFS Pools
zpool list
zfs list -o space

# Dateisysteme
df -h
```

4. **Service-Logs reviewen:**

```bash
# Failed Services
systemctl --failed

# Wichtige Services
journalctl -u caddy -S "1 week ago"
journalctl -u microvm@* -S "1 week ago" | grep -i error
```

#### Monatliche Tasks

1. **Nix Store Cleanup:**

```bash
# Garbage Collection
nix-collect-garbage -d

# Alte Generationen löschen (>30d)
sudo nix-collect-garbage --delete-older-than 30d

# Optimierung (Deduplication)
nix-store --optimise
```

2. **Secrets rotieren (bei Bedarf):**

```bash
cd private
# Neue Secrets generieren
# agenix rekey
```

3. **Backup Restore testen:**

```bash
# Zufällige Datei wiederherstellen
./scripts/test-restore.sh
```

4. **Sicherheits-Updates:**

```bash
# CVE-Check (wenn verfügbar)
nix run nixpkgs#vulnix -- -w $(which systemd)
```

5. **Certificate Expiry prüfen:**

```bash
# Internal CA Certs
sudo find /var/lib/caddy -name "*.crt" -exec openssl x509 -in {} -noout -dates \;

# Let's Encrypt (VPS)
echo | openssl s_client -connect example.com:443 2>/dev/null | \
  openssl x509 -noout -dates
```

---

### Monitoring & Debugging

#### Systemd Services

```bash
# Status aller Services
systemctl status

# Failed Services
systemctl --failed

# Service-Logs
journalctl -u service-name -f  # Follow
journalctl -u service-name -S today  # Seit heute
journalctl -u service-name -S "2024-01-13 10:00"  # Seit Zeitpunkt

# Alle MicroVM Logs
journalctl -u 'microvm@*' -f

# Service neustarten
sudo systemctl restart service-name

# Service Status detailliert
systemctl status service-name -l --no-pager
```

#### MicroVM Debugging

```bash
# MicroVM Status
sudo systemctl status microvm@HL-3-RZ-SAMBA-01

# MicroVM Logs
sudo journalctl -u microvm@HL-3-RZ-SAMBA-01 -f

# In MicroVM Shell (wenn SSH konfiguriert)
ssh root@10.15.40.11

# MicroVM Config ansehen
sudo machinectl show HL-3-RZ-SAMBA-01

# MicroVM neu starten
sudo systemctl restart microvm@HL-3-RZ-SAMBA-01

# MicroVM stoppen
sudo systemctl stop microvm@HL-3-RZ-SAMBA-01
```

#### Network Debugging

```bash
# Interfaces
ip addr show
ip link show

# Bridges
bridge link show

# Routes
ip route show
ip route get 10.15.40.11

# Firewall (nftables)
sudo nft list ruleset
sudo nft list table inet filter

# Connections
ss -tulpn  # Listening ports
ss -o state established  # Established connections

# DNS
dig @10.15.40.21 grafana.czichy.com
nslookup grafana.czichy.com 10.15.40.21

# Ping
ping -c4 10.15.40.11
ping6 -c4 fd00:44::1

# Traceroute
traceroute 10.15.40.11

# Wireguard
sudo wg show
sudo wg show wg0
```

#### ZFS Debugging

```bash
# Pool Status
zpool status -v
zpool list -v

# Dataset Usage
zfs list -o space
zfs list -t all  # Inkl. Snapshots

# I/O Stats
zpool iostat -v 1  # Jede Sekunde

# Scrub
zpool scrub rpool
zpool status  # Scrub Progress

# ARC Stats
arc_summary

# Errors
zpool status -x

# Events
zpool events -v
```

---

### Troubleshooting-Guide

#### Problem: System bootet nicht

**Symptome:**
- Grub startet nicht
- Kernel Panic
- System hängt

**Lösungen:**

1. **Von vorheriger Generation booten:**
   - In Grub: "NixOS - All configurations" → ältere Generation wählen

2. **Von Installer ISO booten:**
   ```bash
   # Pool importieren
   zpool import -f rpool
   
   # Root mounten
   mount -t zfs rpool/local/root /mnt
   mount -t zfs rpool/safe/persist /mnt/persist
   
   # Chroot
   nixos-enter
   
   # Letzte funktionierende Generation aktivieren
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
   sudo /nix/var/nix/profiles/system-123-link/bin/switch-to-configuration boot
   ```

---

#### Problem: MicroVM startet nicht

**Symptome:**
- `systemctl status microvm@...` zeigt failed
- Guest bootet nicht

**Debug:**

```bash
# Logs ansehen
sudo journalctl -u microvm@HL-3-RZ-SAMBA-01 -n 100

# Häufige Ursachen:
# 1. Dataset nicht vorhanden
zfs list | grep samba
sudo zfs create rpool/safe/guests/samba  # Falls fehlt

# 2. Network Interface Konflikt
ip link show | grep mv-samba
sudo ip link delete mv-samba  # Falls existiert

# 3. Config-Fehler
sudo nixos-rebuild switch --flake .#HL-1-MRZ-HOST-01 --show-trace
```

---

#### Problem: Netzwerk funktioniert nicht

**Symptome:**
- Keine Verbindung
- Services nicht erreichbar

**Debug:**

```bash
# 1. Interface Status
ip link show
# Alle Interfaces "UP"?

# 2. IP-Adressen
ip addr show
# IPs korrekt zugewiesen?

# 3. Routes
ip route show
# Default-Route vorhanden?

# 4. DNS
cat /etc/resolv.conf
dig google.com

# 5. Firewall
sudo nft list ruleset | grep -A5 "drop"
# Werden Pakete gedropped?

# 6. Ping
ping 10.15.40.1  # Gateway
ping 1.1.1.1     # Internet
ping google.com  # DNS + Internet

# Lösung: NetworkManager/systemd-networkd neu starten
sudo systemctl restart NetworkManager
# oder
sudo systemctl restart systemd-networkd
```

---

#### Problem: Service antwortet nicht

**Symptome:**
- HTTP 502/504
- Timeout
- Connection refused

**Debug:**

```bash
# 1. Service läuft?
sudo systemctl status caddy
sudo systemctl status microvm@HL-3-RZ-GRAFANA-01

# 2. Port offen?
sudo ss -tulpn | grep :3000

# 3. Firewall?
sudo nft list ruleset | grep 3000

# 4. Logs
sudo journalctl -u caddy -f
sudo journalctl -u microvm@HL-3-RZ-GRAFANA-01 -f

# 5. Reverse Proxy (Caddy)?
# In Guest (z.B. Grafana VM):
curl http://localhost:3000

# Vom Host:
curl http://10.15.40.111:3000

# Von Proxy VM:
curl http://10.15.40.111:3000

# Von Client:
curl http://grafana.czichy.com
```

---

### Performance-Optimierung

#### System

```nix
# Kernel Parameters
boot.kernel.sysctl = {
  # Network Performance
  "net.core.rmem_max" = 134217728;
  "net.core.wmem_max" = 134217728;
  "net.ipv4.tcp_rmem" = "4096 87380 67108864";
  "net.ipv4.tcp_wmem" = "4096 87380 67108864";
  
  # VM Performance
  "vm.swappiness" = 10;
  "vm.vfs_cache_pressure" = 50;
};
```

#### ZFS

```bash
# ARC Size anpassen (z.B. max 8GB)
echo 8589934592 | sudo tee /sys/module/zfs/parameters/zfs_arc_max

# Persistent:
boot.kernelParams = [
  "zfs.zfs_arc_max=8589934592"  # 8GB
];
```

#### Services

```nix
# Systemd Service Optimierung
systemd.services.myservice = {
  serviceConfig = {
    # CPU
    CPUWeight = 100;  # 1-10000, default 100
    CPUQuota = "50%";  # Max 50% CPU
    
    # Memory
    MemoryMax = "1G";
    MemoryHigh = "800M";
    
    # I/O
    IOWeight = 100;  # 1-10000
  };
};
```

---

## 📚 Referenzen & Ressourcen

### Offizielle Dokumentation

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
- **Nix Package Manager**: https://nixos.org/manual/nix/stable/
- **Home-Manager**: https://nix-community.github.io/home-manager/
- **Flakes**: https://nixos.wiki/wiki/Flakes

### Verwendete Tools

- **microvm.nix**: https://github.com/astro/microvm.nix
- **disko**: https://github.com/nix-community/disko
- **agenix**: https://github.com/ryantm/agenix
- **impermanence**: https://github.com/nix-community/impermanence
- **nix-topology**: https://github.com/oddlama/nix-topology

### Security Standards

- **ITSG-22**: Network Security Zoning - Design Considerations for Placement of Services
- **ITSG-38**: Network Security Zoning

### Weitere Ressourcen

- **NixOS & Flakes Book**: https://github.com/ryan4yin/nixos-and-flakes-book
- **Nix Community**: https://discourse.nixos.org/
- **r/NixOS**: https://reddit.com/r/NixOS

---

## 📝 Changelog & Versionen

### System State Version

```nix
system.stateVersion = "25.05";  # NixOS 25.05
home.stateVersion = "25.05";    # Home-Manager 25.05
```

**Wichtig**: `stateVersion` sollte NICHT geändert werden nach initialer Installation!

---

## 🤝 Kontakt & Support

**Repository**: https://github.com/czichy/nixos  
**Issues**: https://github.com/czichy/nixos/issues  
**Autor**: Christian Zichy (czichy)

---

## 📄 Lizenz

Dieses Projekt ist für persönliche/private Nutzung. Bei Verwendung von Code-Teilen bitte Credits geben.

---

**Ende der Dokumentation**

*Generiert am 2026-01-13*  
*NixOS Version: 25.05*  
*Dokumentations-Version: 1.0*
