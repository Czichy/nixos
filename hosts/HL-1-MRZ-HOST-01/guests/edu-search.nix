# Edu-Search MicroVM – Unterrichtsmaterial-Suchsystem
#
# Diese MicroVM enthält:
# - Apache Tika (Textextraktion aus DOCX/PDF/PPTX/ODT/etc.)
# - PostgreSQL (Metadaten + KI-Klassifikationsergebnisse)
# - MeiliSearch (Volltext- + Facettensuche)
# - Python Indexer (Watchdog → Tika → Ollama → PG → MeiliSearch)
# - Nginx + Web-UI (Suchoberfläche für Ina)
#
# Ollama läuft NICHT in dieser MicroVM, sondern nativ auf HOST-01 (GPU).
# Der Indexer greift via HTTP auf HOST-01:11434 zu.
#
# NAS-Shares werden read-only via virtiofs gemountet.
# Originaldateien werden NIEMALS verändert.
{
  globals,
  hostName,
  lib,
  ...
}: let
  # ---------------------------------------------------------------------------
  # Konfiguration
  # ---------------------------------------------------------------------------
  eduDomain = "edu.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";

  # Ollama-Adresse auf dem Host (nativ, GPU-beschleunigt)
  ollamaUrl = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";

  # Ports der internen Services
  webPort = 8080;
  meiliPort = 7700;
  tikaPort = 9998;
in {
  # ---------------------------------------------------------------------------
  # MicroVM-Ressourcen
  # ---------------------------------------------------------------------------
  # 6 GB RAM: Tika (~512MB JVM) + PostgreSQL (~128MB) + MeiliSearch (~200MB)
  #           + Python Indexer (~100MB) + Nginx (~10MB) + OS-Overhead
  # HOST-01 hat 64GB RAM, davon 34GB frei → kein Engpass.
  microvm.mem = 1024 * 6;
  microvm.vcpu = 4;

  networking.hostName = hostName;

  # ---------------------------------------------------------------------------
  # NAS-Shares als virtiofs in die MicroVM mounten
  # ---------------------------------------------------------------------------
  # Diese Shares sind READ-ONLY für den Indexer.
  # Die Originaldateien werden niemals verändert.
  #
  # HINWEIS: virtiofs sendet nicht zuverlässig inotify-Events, daher nutzt
  # der Python-Indexer PollingObserver statt inotify-basiertem Watchdog.
  microvm.shares = [
    {
      # Inas Schulunterlagen (via Syncthing synchronisiert)
      source = "/shared/shares/users/ina";
      mountPoint = "/nas/ina";
      tag = "edu-ina";
      proto = "virtiofs";
    }
    {
      # Bibliothek (gemeinsame Sammlung)
      source = "/storage/shares/bibliothek";
      mountPoint = "/nas/bibliothek";
      tag = "edu-bib";
      proto = "virtiofs";
    }
    {
      # Dokumente (gemeinsame Dokumente)
      source = "/storage/shares/dokumente";
      mountPoint = "/nas/dokumente";
      tag = "edu-dok";
      proto = "virtiofs";
    }
  ];

  # ---------------------------------------------------------------------------
  # Sub-Module importieren
  # ---------------------------------------------------------------------------
  imports = [
    ./edu-search/tika.nix
    ./edu-search/postgresql.nix
    ./edu-search/meilisearch.nix
    ./edu-search/indexer.nix
    ./edu-search/webui.nix
    ./edu-search/backup.nix
  ];

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  networking.firewall.allowedTCPPorts = [
    webPort   # Nginx Web-UI (über Caddy Reverse Proxy erreichbar)
    meiliPort # MeiliSearch API (für Web-UI JavaScript-Client)
    5432      # PostgreSQL für n8n Read-Only-Zugriff (Workflows: Reports, Benachrichtigungen)
  ];

  # ---------------------------------------------------------------------------
  # Umgebungsvariablen für alle edu-search Services
  # ---------------------------------------------------------------------------
  # Diese werden von den Sub-Modulen (indexer.nix etc.) referenziert.
  # Zentral definiert um Konsistenz sicherzustellen.
  environment.variables = {
    EDU_OLLAMA_URL = ollamaUrl;
    EDU_TIKA_URL = "http://127.0.0.1:${toString tikaPort}";
    EDU_MEILI_URL = "http://127.0.0.1:${toString meiliPort}";
    EDU_MEILI_INDEX = "edu_documents";
    EDU_DB_HOST = "127.0.0.1";
    EDU_DB_PORT = "5432";
    EDU_DB_NAME = "edu_search";
    EDU_DB_USER = "edu_indexer";
  };

  # ---------------------------------------------------------------------------
  # Impermanence
  # ---------------------------------------------------------------------------
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    # Verzeichnis-Persistenz wird in den Sub-Modulen definiert:
    # - postgresql.nix: /var/lib/postgresql
    # - meilisearch.nix: /var/lib/meilisearch
    # - indexer.nix: /var/lib/edu-indexer
  };

  # ---------------------------------------------------------------------------
  # Service-Registrierung in globals (Homepage, Monitoring, etc.)
  # ---------------------------------------------------------------------------
  globals.services.edu-search = {
    domain = eduDomain;
    homepage = {
      enable = true;
      name = "Edu-Search";
      icon = "sh-meilisearch";
      description = "Unterrichtsmaterial-Suche (Englisch/Spanisch) mit KI-Klassifikation";
      category = "Documents & Notes";
      requiresAuth = true;
      priority = 25;
      abbr = "EDU";
    };
  };

  # ---------------------------------------------------------------------------
  # Reverse Proxy: Caddy (intern + extern)
  # ---------------------------------------------------------------------------

  # Interner Caddy auf HOST-02 (vlan40 → MicroVM)
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${eduDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4}:${toString webPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # Externer Caddy auf PAZ-PROXY-01 (Internet → interner Caddy)
  # Abgesichert über oauth2-proxy → Kanidm SSO.
  # Zugriff wird über die Kanidm-Gruppe "web-sentinel.edu-search" gesteuert.
  # Nur Benutzer in dieser Gruppe (christian, ina) können edu-search erreichen.
  #
  # Authentifizierungs-Fluss:
  #   Browser → Caddy (forward_auth) → oauth2-proxy → Kanidm Login
  #           → Session-Cookie → Weiterleitung an edu-search
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${eduDomain}".extraConfig = ''
        forward_auth localhost:4180 {
            uri /oauth2/auth?allowed_groups=access_edu_search
            copy_headers X-Auth-Request-User X-Auth-Request-Email X-Auth-Request-Groups
        }
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                tls_insecure_skip_verify
                tls_server_name ${eduDomain}
            }
        }
        import czichy_headers
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Monitoring
  # ---------------------------------------------------------------------------
  globals.monitoring.http.edu-search = {
    url = "http://${globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4}:${toString webPort}";
    expectedBodyRegex = "Unterrichtsmaterial";
    network = "vlan40";
  };

  globals.monitoring.tcp.edu-search-meili = {
    host = globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4;
    port = meiliPort;
    network = "vlan40";
  };

  # ---------------------------------------------------------------------------
  # Boot / Netzwerk
  # ---------------------------------------------------------------------------
  fileSystems = lib.mkMerge [
    {"/state".neededForBoot = true;}
  ];

  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
