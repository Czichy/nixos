# Homepage Dashboard - Automatische Service-Registrierung

## Übersicht

Diese Implementierung ermöglicht die **automatische Generierung** der Homepage-Dashboard-Services basierend auf den bereits im System konfigurierten Services in `globals.services`.

### Vorteile

✅ **Single Source of Truth**: Services definieren ihre Metadaten einmal  
✅ **Automatische Synchronisation**: Neue Services erscheinen automatisch auf der Homepage  
✅ **Typsicher**: NixOS-Module validieren alle Metadaten  
✅ **Flexibel**: Services können Homepage-Darstellung individuell steuern  
✅ **Konsistent**: Gleiche Muster wie bei Caddy-Registrierung

---

## Implementierungsplan

### Phase 1: Globals-Modul erweitern

**Datei:** `modules/globals.nix`

Die `services`-Option wird um Homepage-spezifische Metadaten erweitert:

```nix
services = mkOption {
  type = types.attrsOf (types.submodule {
    options = {
      domain = mkOption {
        type = types.str;
        description = "The domain under which this service can be reached";
      };
      
      # NEU: Homepage-spezifische Metadaten
      homepage = mkOption {
        default = {};
        type = types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to show this service on the homepage";
            };
            
            name = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Display name on homepage (defaults to service name)";
            };
            
            icon = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Icon identifier (sh-xxx, si-xxx, mdi-xxx)";
              example = "sh-grafana";
            };
            
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Service description shown on homepage";
            };
            
            category = mkOption {
              type = types.str;
              default = "Services";
              description = "Service category for grouping";
              example = "Monitoring & Observability";
            };
            
            requiresAuth = mkOption {
              type = types.bool;
              default = false;
              description = "Whether service requires authentication";
            };
            
            priority = mkOption {
              type = types.int;
              default = 100;
              description = "Sort priority within category (lower = higher on page)";
            };
            
            # Zusätzliche Felder für Homepage-Dashboard
            abbr = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Abbreviation shown on service card";
            };
            
            ping = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "URL for health check ping";
            };
          };
        };
      };
    };
  });
};
```

---

### Phase 2: Service-Konfigurationen aktualisieren

**Beispiel 1: Grafana** (`hosts/HL-1-MRZ-HOST-01/guests/grafana.nix`)

```nix
globals.services.grafana = {
  domain = grafanaDomain;
  homepage = {
    enable = true;
    name = "Grafana";
    icon = "sh-grafana";
    description = "Metrics Visualization & Dashboards";
    category = "Monitoring & Observability";
    requiresAuth = false;
    priority = 10;
  };
};
```

**Beispiel 2: Vaultwarden** (`hosts/HL-1-MRZ-HOST-02/guests/vaultwarden.nix`)

```nix
globals.services.vaultwarden = {
  domain = vaultwardenDomain;
  homepage = {
    enable = true;
    name = "Vaultwarden";
    icon = "sh-bitwarden";
    description = "Password Manager (Bitwarden)";
    category = "Security & Authentication";
    requiresAuth = true;
    priority = 5;
  };
};
```

**Beispiel 3: Forgejo** (`hosts/HL-1-MRZ-HOST-01/guests/forgejo.nix`)

```nix
globals.services.forgejo = {
  domain = forgejoDomain;
  homepage = {
    enable = true;
    name = "Forgejo";
    icon = "sh-forgejo";
    description = "Self-hosted Git Service";
    category = "Development & Collaboration";
    requiresAuth = false;
    priority = 20;
  };
};
```

---

### Phase 3: Homepage automatisch generieren

**Datei:** `hosts/HL-1-MRZ-HOST-03/guests/homepage.nix`

#### Neue Implementierung mit automatischer Generierung:

```nix
{
  config,
  globals,
  secretsPath,
  hostName,
  pkgs,
  lib,
  ...
}:
let
  domain = "home.czichy.com";
  certloc = "/var/lib/acme-sync/czichy.com";
  listenPort = 10001;

  # =====================================================================
  # AUTOMATIC SERVICE GENERATION FROM GLOBALS
  # =====================================================================
  
  # Alle aktivierten Services aus globals filtern
  enabledServices = lib.filterAttrs 
    (_: svc: (svc.homepage.enable or false) && (svc ? domain))
    globals.services;
  
  # Service zu Homepage-Format konvertieren
  mkHomepageService = serviceName: svc: 
    let
      displayName = svc.homepage.name or serviceName;
      serviceUrl = "https://${svc.domain}";
    in {
      ${displayName} = [{
        icon = svc.homepage.icon or "mdi-web";
        href = serviceUrl;
        description = svc.homepage.description or "${displayName} Service";
      }] ++ lib.optional (svc.homepage.abbr or null != null) {
        abbr = svc.homepage.abbr;
      } ++ lib.optional (svc.homepage.ping or null != null) {
        ping = svc.homepage.ping;
      };
    };
  
  # Nach Kategorie gruppieren
  servicesByCategory = lib.groupBy 
    (svc: svc.homepage.category or "Services") 
    (lib.mapAttrsToList (name: svc: svc // { _name = name; }) enabledServices);
  
  # Kategorie zu Homepage-Format konvertieren
  mkCategory = categoryName: services:
    let
      # Nach Priorität sortieren (niedrigere Priorität = höher)
      sortedServices = lib.sort 
        (a: b: (a.homepage.priority or 100) < (b.homepage.priority or 100))
        services;
    in {
      ${categoryName} = map 
        (svc: mkHomepageService svc._name svc) 
        sortedServices;
    };
  
  # Generierte Services
  generatedServices = lib.mapAttrsToList mkCategory servicesByCategory;
  
  # =====================================================================
  # STATIC BOOKMARKS (wie bisher)
  # =====================================================================
  
  staticBookmarks = [
    {
      "Homelab Resources" = [
        {
          nixos = [{
            icon = "sh-nixos";
            href = "https://nixos.org/";
            description = "Declarative Linux distribution";
          }];
        }
        {
          "nix-topology" = [{
            icon = "sh-nixos";
            href = "https://github.com/oddlama/nix-topology";
            description = "Network topology visualization";
          }];
        }
        # ... weitere static bookmarks
      ];
    }
  ];

in {
  microvm.mem = 512;
  microvm.vcpu = 1;
  
  networking.hostName = hostName;
  
  networking.firewall = {
    allowedTCPPorts = [443 listenPort];
  };
  
  # Caddy-Registrierung (wie bisher)
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${domain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-HOME-01".ipv4}:${toString listenPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  
  # Homepage-Service-Konfiguration
  services.homepage-dashboard = {
    enable = true;
    listenPort = listenPort;
    allowedHosts = domain;
    
    settings = {
      title = "Homelab Services";
      description = "Zentrale Übersicht aller Services im Homelab";
      hideVersion = true;
    };
    
    widgets = [
      {
        openmeteo = {
          label = "Idstein";
          latitude = 50.248329;
          longitude = 8.256039;
          units = "metric";
          cache = 5;
        };
      }
      {
        resources = {
          cpu = true;
          disk = "/";
          memory = true;
        };
      }
      {
        search = {
          provider = "google";
          focus = true;
          showSearchSuggestions = true;
          target = "_self";
        };
      }
    ];
    
    # AUTOMATISCH GENERIERTE SERVICES
    services = generatedServices;
    
    # STATISCHE BOOKMARKS
    bookmarks = staticBookmarks;
  };
  
  # Secrets & Persistence (wie bisher)
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };
  
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [];
  };
}
```

---

## Migration bestehender Services

### Schritt 1: Metadaten hinzufügen

Für **jeden Service** in `hosts/*/guests/*.nix`, der bereits `globals.services.<name>.domain` definiert:

1. **Homepage-Block hinzufügen:**

```nix
globals.services.<servicename> = {
  domain = <domain>;
  # NEU:
  homepage = {
    enable = true;  # oder false, wenn nicht auf Homepage
    name = "Display Name";
    icon = "sh-icon";  # oder si-, mdi-
    description = "Service-Beschreibung";
    category = "Kategorie";
    requiresAuth = false;  # oder true
    priority = 50;  # Sortierung innerhalb Kategorie
  };
};
```

2. **Icon-Referenzen:**
   - `sh-` = https://selfh.st/icons/
   - `si-` = https://simpleicons.org/
   - `mdi-` = https://pictogrammers.com/library/mdi/

### Schritt 2: Kategorien definieren

**Vorgeschlagene Kategorien:**

- **Storage & Files**: Samba, Syncthing, Minio
- **Documents & Notes**: Paperless, Ente, Affine
- **Development & Collaboration**: Forgejo, Docspell
- **Monitoring & Observability**: Grafana, InfluxDB, Parseable
- **Infrastructure**: AdGuard Home, Vaultwarden
- **Home Automation**: Home Assistant, Node-RED, Mosquitto
- **Network & Management**: Unifi Controller, Homepage
- **Security & Authentication**: Vaultwarden

### Schritt 3: Services nach Priorität ordnen

**Prioritäten-Richtlinie:**
- `1-20`: Kritische/häufig genutzte Services
- `21-50`: Wichtige Services
- `51-100`: Standard-Services
- `101+`: Selten genutzte Services

---

## Beispiel-Migration: Alle Services

### Monitoring & Observability

```nix
# grafana.nix
globals.services.grafana = {
  domain = grafanaDomain;
  homepage = {
    enable = true;
    name = "Grafana";
    icon = "sh-grafana";
    description = "Metrics Visualization & Dashboards";
    category = "Monitoring & Observability";
    priority = 10;
  };
};

# influxdb.nix
globals.services.influxdb = {
  domain = influxDomain;
  homepage = {
    enable = true;
    name = "InfluxDB";
    icon = "sh-influxdb";
    description = "Time-Series Database";
    category = "Monitoring & Observability";
    priority = 20;
  };
};

# parseable.nix
globals.services.parseable = {
  domain = parseableDomain;
  homepage = {
    enable = true;
    name = "Parseable";
    icon = "sh-parseable";
    description = "Log Aggregation & Search";
    category = "Monitoring & Observability";
    priority = 30;
  };
};
```

### Storage & Files

```nix
# samba.nix
globals.services.samba = {
  domain = sambaDomain;
  homepage = {
    enable = true;
    name = "Samba";
    icon = "mdi-folder-network";
    description = "Network File Sharing";
    category = "Storage & Files";
    priority = 5;
  };
};

# syncthing.nix
globals.services.syncthing = {
  domain = syncthingDomain;
  homepage = {
    enable = true;
    name = "Syncthing";
    icon = "sh-syncthing";
    description = "File Synchronization";
    category = "Storage & Files";
    priority = 10;
  };
};

# s3.nix (Minio)
globals.services.s3 = {
  domain = s3Domain;
  homepage = {
    enable = true;
    name = "Minio (S3)";
    icon = "sh-minio";
    description = "Object Storage";
    category = "Storage & Files";
    priority = 20;
  };
};
```

### Development & Collaboration

```nix
# forgejo.nix
globals.services.forgejo = {
  domain = forgejoDomain;
  homepage = {
    enable = true;
    name = "Forgejo";
    icon = "sh-forgejo";
    description = "Self-hosted Git Service";
    category = "Development & Collaboration";
    priority = 5;
  };
};

# affine.nix
globals.services.affine = {
  domain = affineDomain;
  homepage = {
    enable = true;
    name = "Affine";
    icon = "mdi-notebook";
    description = "Knowledge Base & Notes";
    category = "Development & Collaboration";
    priority = 10;
  };
};
```

### Documents & Notes

```nix
# paperless.nix
globals.services.paperless = {
  domain = paperlessDomain;
  homepage = {
    enable = true;
    name = "Paperless-ngx";
    icon = "sh-paperless";
    description = "Document Management & OCR";
    category = "Documents & Notes";
    priority = 5;
  };
};

# ente.nix
globals.services.ente = {
  domain = enteDomain;
  homepage = {
    enable = true;
    name = "Ente";
    icon = "mdi-image-multiple";
    description = "Encrypted Photo Backup";
    category = "Documents & Notes";
    priority = 10;
  };
};
```

### Infrastructure

```nix
# adguardhome.nix
globals.services.adguardhome = {
  domain = adguardDomain;
  homepage = {
    enable = true;
    name = "AdGuard Home";
    icon = "sh-adguard";
    description = "Network-wide Ad Blocking & DNS";
    category = "Infrastructure";
    priority = 5;
  };
};

# vaultwarden.nix
globals.services.vaultwarden = {
  domain = vaultwardenDomain;
  homepage = {
    enable = true;
    name = "Vaultwarden";
    icon = "sh-bitwarden";
    description = "Password Manager";
    category = "Infrastructure";
    requiresAuth = true;
    priority = 1;
  };
};
```

### Home Automation

```nix
# hass.nix
globals.services.hass = {
  domain = hassDomain;
  homepage = {
    enable = true;
    name = "Home Assistant";
    icon = "sh-home-assistant";
    description = "Smart Home Hub";
    category = "Home Automation";
    priority = 5;
  };
};

# node-red.nix
globals.services.nodered = {
  domain = noderedDomain;
  homepage = {
    enable = true;
    name = "Node-RED";
    icon = "sh-node-red";
    description = "Flow-based Automation";
    category = "Home Automation";
    priority = 10;
  };
};

# mosquitto.nix
globals.services.mosquitto = {
  domain = mosquittoDomain;
  homepage = {
    enable = false;  # Kein Web-UI
    name = "Mosquitto";
    icon = "mdi-message-processing";
    description = "MQTT Broker";
    category = "Home Automation";
  };
};
```

### Network & Management

```nix
# unifi.nix
globals.services.unifi = {
  domain = unifiDomain;
  homepage = {
    enable = true;
    name = "Unifi Controller";
    icon = "sh-unifi";
    description = "Network Management";
    category = "Network & Management";
    priority = 10;
  };
};

# homepage.nix (selbst)
globals.services.homepage = {
  domain = "home.czichy.com";
  homepage = {
    enable = false;  # Nicht auf eigener Seite
    name = "Homepage";
    icon = "mdi-view-dashboard";
    description = "Service Dashboard";
    category = "Network & Management";
  };
};
```

---

## Vorteile der Lösung

### 1. Automatisierung
- **Neue Services**: Automatisch auf Homepage, sobald `globals.services.<name>` definiert
- **Kein Duplikat**: Domain nur einmal definieren
- **Konsistent**: Gleicher Mechanismus wie Caddy-Registrierung

### 2. Wartbarkeit
- **Single Source**: Service-Metadaten zentral im Service selbst
- **Typsicherheit**: NixOS validiert alle Optionen
- **Refactoring**: Änderungen propagieren automatisch

### 3. Flexibilität
- **Opt-out**: Services können `homepage.enable = false` setzen
- **Kategorien**: Frei definierbar und gruppierbar
- **Prioritäten**: Sortierung innerhalb Kategorien
- **Erweitern**: Neue Felder einfach hinzufügbar

### 4. DRY-Prinzip
```nix
# Vorher: 3 Stellen pflegen
globals.services.grafana.domain = "grafana.czichy.com";
globals.monitoring.http.grafana = { url = "https://grafana.czichy.com"; ... };
services.homepage-dashboard.services = [ { Grafana = ...; } ];

# Nachher: 1 Stelle pflegen
globals.services.grafana = {
  domain = "grafana.czichy.com";
  homepage = { enable = true; name = "Grafana"; ... };
};
```

---

## Testing

### 1. Syntax-Check

```bash
nix flake check
```

### 2. Build Homepage

```bash
nixos-rebuild build --flake .#HL-1-MRZ-HOST-03
```

### 3. Deploy

```bash
nixos-rebuild switch --flake .#HL-1-MRZ-HOST-03 --target-host root@10.15.100.30
```

### 4. Verifizieren

```bash
# Homepage neu laden
systemctl restart homepage-dashboard

# Config inspizieren
systemctl cat homepage-dashboard

# Logs prüfen
journalctl -u homepage-dashboard -f
```

---

## Rollout-Plan

### Phase 1: Infrastruktur (Tag 1)
1. ✅ `modules/globals.nix` erweitern
2. ✅ Commit & Push

### Phase 2: Core Services (Tag 2-3)
1. Top 5 Services migrieren (Vaultwarden, Grafana, Home Assistant, Forgejo, AdGuard)
2. Homepage.nix auf automatische Generierung umstellen
3. Testen auf dev/staging

### Phase 3: Alle Services (Tag 4-7)
1. Batch-Migration aller restlichen Services
2. Kategorien finalisieren
3. Icons & Descriptions optimieren

### Phase 4: Cleanup (Tag 8)
1. Alte statische Homepage-Config entfernen
2. Dokumentation aktualisieren
3. Optional: Monitoring-Integration

---

## Erweiterungsmöglichkeiten

### 1. Health Checks Integration

```nix
homepage = {
  # ... existing options
  ping = "https://${svc.domain}/api/health";
  widget = {
    type = "grafana";
    url = "https://${svc.domain}";
    username = "...";
    password = "...";
  };
};
```

### 2. Automatische Widgets

```nix
# Automatisch Widget basierend auf Service-Typ
mkWidget = serviceName: svc: 
  if serviceName == "grafana" then {
    type = "grafana";
    url = "https://${svc.domain}";
    # credentials...
  }
  else null;
```

### 3. Multi-Homepage Support

```nix
# Verschiedene Homepages für verschiedene User/Zonen
services.homepage-dashboard-admin = { ... };
services.homepage-dashboard-family = { ... };
services.homepage-dashboard-public = { ... };
```

### 4. Dynamic Icons

```nix
# Icons aus Service-Namen ableiten
defaultIcon = serviceName:
  if serviceName == "grafana" then "sh-grafana"
  else if serviceName == "influxdb" then "sh-influxdb"
  else "mdi-web";
```

---

## Troubleshooting

### Problem: Service erscheint nicht auf Homepage

**Check 1: Domain definiert?**
```bash
nix eval .#nixosConfigurations.HL-1-MRZ-HOST-03.config.globals.services.myservice.domain
```

**Check 2: Homepage enabled?**
```bash
nix eval .#nixosConfigurations.HL-1-MRZ-HOST-03.config.globals.services.myservice.homepage.enable
```

**Check 3: Generierte Services inspizieren**
```bash
nix eval .#nixosConfigurations.HL-1-MRZ-HOST-03.config.services.homepage-dashboard.services --json | jq
```

### Problem: Icon wird nicht angezeigt

**Verfügbare Icon-Sets:**
- https://selfh.st/icons/ → `sh-<name>`
- https://simpleicons.org/ → `si-<name>`
- https://pictogrammers.com/library/mdi/ → `mdi-<name>`

**Fallback:**
```nix
icon = "mdi-web";  # Generic fallback
```

### Problem: Kategorien falsch sortiert

**Lösung:** Kategorienamen alphabetisch sortiert

```nix
# Wenn bestimmte Reihenfolge gewünscht:
categoryOrder = [ "Infrastructure" "Monitoring" "Development" "Storage" ];
```

---

## Referenzen

- **Homepage Dashboard Docs**: https://gethomepage.dev/
- **Nix Module System**: https://nixos.org/manual/nixos/stable/#sec-writing-modules
- **Distributed Config Pattern**: `/modules/nixos/misc/distributed-config.nix`
- **Globals Module**: `/modules/globals.nix`

---

**Autor**: Generated based on project analysis  
**Datum**: 2026-01-13  
**Version**: 1.0
