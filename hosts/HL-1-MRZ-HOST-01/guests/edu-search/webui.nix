# Nginx Web-UI für Edu-Search
#
# Serviert die statische Single-Page-Application (SPA) für die
# Unterrichtsmaterial-Suche und proxied die MeiliSearch-API.
#
# Die SPA besteht aus:
# - index.html: Suchoberfläche mit Suchfeld + Filter-Dropdowns + Ergebnisliste
# - style.css: Einfaches, übersichtliches Design (optimiert für Nicht-Techniker)
# - app.js: MeiliSearch-Client mit Debounce-Suche und Faceted Filtering
#
# Der Nginx-Server:
# - Serviert die statischen Dateien unter /
# - Proxied /meili/ → MeiliSearch API (127.0.0.1:7700)
#   Damit kann die SPA direkt aus dem Browser suchen ohne CORS-Probleme.
#
# Erreichbar über:
# - Intern: http://HL-3-RZ-EDU-01:8080
# - Extern: https://edu.czichy.com (via Caddy Reverse Proxy auf HOST-02)
{
  pkgs,
  ...
}: let
  webPort = 8080;
  meiliHost = "127.0.0.1";
  meiliPort = 7700;

  # ---------------------------------------------------------------------------
  # Statische Web-UI Dateien als Nix-Derivation
  # ---------------------------------------------------------------------------
  # Die Dateien werden in den Nix-Store kopiert und von Nginx ausgeliefert.
  # Änderungen an den HTML/CSS/JS-Dateien erfordern ein `nixos-rebuild`.
  eduWebUI = pkgs.runCommand "edu-search-webui" {} ''
    mkdir -p $out
    cp ${./webui/index.html} $out/index.html
    cp ${./webui/style.css} $out/style.css
    cp ${./webui/app.js} $out/app.js
  '';
in {
  # ---------------------------------------------------------------------------
  # Nginx als statischer Webserver + MeiliSearch API-Proxy
  # ---------------------------------------------------------------------------
  services.nginx = {
    enable = true;

    # Empfohlene Defaults für einen internen Webserver
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;

    virtualHosts."edu-search" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = webPort;
        }
      ];

      root = "${eduWebUI}";

      # SPA-Routing: Alle nicht-existierenden Pfade → index.html
      locations."/" = {
        index = "index.html";
        tryFiles = "$uri $uri/ /index.html";
        extraConfig = ''
          # Cache-Control für statische Assets
          expires 1h;
          add_header Cache-Control "public, no-transform";
        '';
      };

      # MeiliSearch API-Proxy
      # Die SPA ruft /meili/indexes/edu_documents/search auf,
      # Nginx leitet das weiter an http://127.0.0.1:7700/indexes/edu_documents/search
      #
      # Authentifizierung wird SERVERSEITIG injiziert:
      # Der edu-search-meili-key.service (meilisearch.nix) erzeugt
      # /run/edu-search/meili-auth.conf mit dem Authorization-Header.
      # Das Frontend (app.js) muss keinen Key kennen.
      locations."/meili/" = {
        proxyPass = "http://${meiliHost}:${toString meiliPort}/";
        extraConfig = ''
          # MeiliSearch Auth-Header serverseitig injizieren
          # Datei wird von edu-search-meili-key.service erzeugt und enthält:
          #   proxy_set_header Authorization "Bearer <master-key>";
          include /run/edu-search/meili-auth.conf;

          # Proxy-Header
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # CORS-Header (für lokale Entwicklung und Cross-Origin-Zugriff)
          add_header Access-Control-Allow-Origin "*" always;
          add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE" always;
          add_header Access-Control-Allow-Headers "Content-Type" always;

          # Preflight-Requests (OPTIONS) sofort beantworten
          if ($request_method = 'OPTIONS') {
            add_header Access-Control-Allow-Origin "*";
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE";
            add_header Access-Control-Allow-Headers "Content-Type";
            add_header Access-Control-Max-Age 86400;
            add_header Content-Length 0;
            add_header Content-Type "text/plain charset=UTF-8";
            return 204;
          }

          # Timeouts für MeiliSearch (Suche ist normalerweise < 50ms)
          proxy_connect_timeout 5s;
          proxy_read_timeout 30s;
          proxy_send_timeout 10s;

          # Request-Body-Limit für Suchanfragen (POST mit JSON-Body)
          client_max_body_size 1m;
        '';
      };

      # Health-Check Endpoint (für Monitoring)
      locations."/health" = {
        extraConfig = ''
          access_log off;
          return 200 '{"status":"ok","service":"edu-search-webui"}';
          add_header Content-Type "application/json";
        '';
      };

      # Favicon / Robots
      locations."= /favicon.ico" = {
        extraConfig = ''
          access_log off;
          log_not_found off;
          return 204;
        '';
      };

      locations."= /robots.txt" = {
        extraConfig = ''
          access_log off;
          return 200 "User-agent: *\nDisallow: /\n";
          add_header Content-Type "text/plain";
        '';
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  # Der Web-Port wird bereits in edu-search.nix geöffnet.
  # Hier nicht nochmal öffnen um Duplikate zu vermeiden.
  # networking.firewall.allowedTCPPorts = [ webPort ];

  # ---------------------------------------------------------------------------
  # Nginx braucht keine Persistenz – rein statisch, kein State.
  # ---------------------------------------------------------------------------
}
