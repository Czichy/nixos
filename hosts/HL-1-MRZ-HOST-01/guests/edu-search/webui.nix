# Nginx Web-UI für Edu-Search
#
# Serviert die statische Single-Page-Application (SPA) für die
# Unterrichtsmaterial-Suche und proxied die MeiliSearch-API.
#
# Die SPA besteht aus:
# - index.html: Suchoberfläche mit Suchfeld + Filter-Dropdowns + Ergebnisliste
# - style.css: Design inkl. Preview-Modal (optimiert für Nicht-Techniker)
# - edu-config.js:  Konstanten, Datei-Icons, Preview-Type-Erkennung
# - edu-utils.js:   HTML-Escaping, Clipboard, URL-Encoding, Filepath→URL
# - edu-preview.js: Vorschau-Modal (PDF, Bilder, Audio, Video, Text inline)
# - edu-cards.js:   Ergebnis-Karten mit Vorschau/Download/Pfad-kopieren Buttons
# - edu-search.js:  MeiliSearch-Suche, Filter, Event-Binding, Initialisierung
#
# Der Nginx-Server:
# - Serviert die statischen Dateien unter /
# - Serviert NAS-Dateien unter /files/ für Vorschau & Download (read-only)
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
    cp ${./webui/edu-config.js} $out/edu-config.js
    cp ${./webui/edu-utils.js} $out/edu-utils.js
    cp ${./webui/edu-preview.js} $out/edu-preview.js
    cp ${./webui/edu-cards.js} $out/edu-cards.js
    cp ${./webui/edu-search.js} $out/edu-search.js
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

    # -----------------------------------------------------------------------
    # Map-Direktive für Content-Disposition (auf http-Ebene)
    # -----------------------------------------------------------------------
    # Bestimmt anhand der Dateiendung ob eine Datei inline (Vorschau im
    # Browser) oder als attachment (Download erzwingen) ausgeliefert wird.
    #
    # WICHTIG: Muss auf http-Ebene stehen, NICHT in location/server.
    # Vermeidet das Nginx-Problem "add_header in if-Blöcken löscht
    # Parent-Header" (gixy: add_header_redefinition).
    appendHttpConfig = ''
      map $uri $edu_content_disposition {
        default                      "attachment";
        # Vorschau-fähig: inline anzeigen
        ~*\.pdf$                     "inline";
        ~*\.jpe?g$                   "inline";
        ~*\.png$                     "inline";
        ~*\.gif$                     "inline";
        ~*\.svg$                     "inline";
        ~*\.webp$                    "inline";
        ~*\.bmp$                     "inline";
        ~*\.tiff?$                   "inline";
        ~*\.txt$                     "inline";
        ~*\.csv$                     "inline";
        ~*\.md$                      "inline";
        ~*\.xml$                     "inline";
        ~*\.json$                    "inline";
      }
    '';

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

      # ---------------------------------------------------------------
      # Datei-Download / Vorschau – NAS-Dateien direkt ausliefern
      # ---------------------------------------------------------------
      # Die Dateien liegen in der MicroVM unter /nas/{ina,bibliothek,dokumente}.
      # Der Indexer speichert filepath als z.B. "/nas/ina/schule/test.pdf".
      # Das Frontend baut daraus: /files/ina/schule/test.pdf
      #
      # Sicherheit:
      # - Read-only: Nginx darf nur lesen (NAS ist read-only gemountet)
      # - Kein Directory-Listing (autoindex off)
      # - Authentifizierung erfolgt über Caddy → oauth2-proxy → Kanidm
      #   (der /files/ Pfad ist hinter dem gleichen Auth-Flow wie die Web-UI)
      locations."/files/" = {
        alias = "/nas/";
        extraConfig = ''
          # Kein Directory-Listing
          autoindex off;

          # Symlinks nicht folgen (Sicherheit)
          disable_symlinks on;

          # MIME-Types korrekt setzen (Nginx erkennt die meisten automatisch)
          types {
            application/pdf                       pdf;
            image/jpeg                            jpg jpeg;
            image/png                             png;
            image/gif                             gif;
            image/svg+xml                         svg;
            image/webp                            webp;
            text/plain                            txt md csv;
            text/html                             html htm;
            application/vnd.openxmlformats-officedocument.wordprocessingml.document   docx;
            application/vnd.openxmlformats-officedocument.presentationml.presentation pptx;
            application/vnd.openxmlformats-officedocument.spreadsheetml.sheet         xlsx;
            application/msword                    doc;
            application/vnd.ms-powerpoint         ppt;
            application/vnd.ms-excel              xls;
            application/vnd.oasis.opendocument.text          odt;
            application/vnd.oasis.opendocument.presentation  odp;
            application/vnd.oasis.opendocument.spreadsheet   ods;
            application/rtf                       rtf;
            application/epub+zip                  epub;
            audio/mpeg                            mp3;
            audio/mp4                             m4a;
            audio/wav                             wav;
            audio/ogg                             ogg;
            audio/flac                            flac;
            video/mp4                             mp4;
            video/webm                            webm;
          }

          # Content-Disposition via map-Variable (keine if-Blöcke nötig)
          # PDFs, Bilder, Text → inline (Vorschau im Browser)
          # Office, Audio, Video → attachment (Download erzwingen)
          add_header Content-Disposition $edu_content_disposition always;

          # Sicherheits-Header
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Cache-Control "private, max-age=3600";

          # Große Dateien erlauben (Präsentationen, Videos)
          client_max_body_size 0;

          # Sendfile für effiziente Dateiübertragung
          sendfile on;
          tcp_nopush on;
          tcp_nodelay on;
        '';
      };

      # MeiliSearch API-Proxy
      # Die SPA ruft /meili/indexes/edu_documents/search auf,
      # Nginx leitet das weiter an http://127.0.0.1:7700/indexes/edu_documents/search
      #
      # Authentifizierung wird SERVERSEITIG injiziert:
      # Der edu-search-meili-key.service (meilisearch.nix) erzeugt
      # /run/edu-search/meili-auth.conf mit dem Authorization-Header.
      # Das Frontend muss keinen Key kennen.
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
