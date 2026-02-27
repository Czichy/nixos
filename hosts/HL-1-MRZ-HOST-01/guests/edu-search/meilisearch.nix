# MeiliSearch für Edu-Search Volltext- und Facettensuche
#
# MeiliSearch ist die Suchengine, die von der Web-UI direkt angesprochen wird.
# Sie bietet:
# - Typo-tolerante Volltextsuche (perfekt für Ina)
# - Faceted Search mit filterbaren Attributen (Dropdowns: Fach, Klasse, Typ, Niveau)
# - Sortierbare Ergebnisse (nach Klasse, Dateiname, Änderungsdatum)
# - Sub-50ms Antwortzeiten bei kleinen bis mittleren Datenmengen
#
# Warum MeiliSearch statt Elasticsearch?
# - Deutlich leichter (RAM: ~100-200MB vs. ~2GB für Elasticsearch)
# - Offizielles NixOS-Modul vorhanden (`services.meilisearch`)
# - Kein Docker nötig
# - Typo-Toleranz out-of-the-box
# - Faceted Search / Filterbare Attribute = ideal für Dropdowns in der UI
# - Bereits teilweise in der bestehenden Infrastruktur konfiguriert gewesen
#
# Die Index-Konfiguration (filterableAttributes, sortableAttributes, etc.)
# wird vom Python-Indexer beim Start gesetzt (idempotent).
#
# BACKUP: ⚠️ Optional – MeiliSearch kann jederzeit aus PostgreSQL-Daten
# + NAS-Dateien neu aufgebaut werden. Ein Rebuild-Skript ist geplant.
#
# SECRET: Der Master-Key wird via agenix verwaltet.
# Pfad im private-Repo:
#   hosts/HL-1-MRZ-HOST-01/guests/edu-search/meilisearch-master-key.age
# Erzeugen:
#   openssl rand -base64 32 > /tmp/meili-key
#   agenix -e hosts/HL-1-MRZ-HOST-01/guests/edu-search/meilisearch-master-key.age < /tmp/meili-key
#   rm /tmp/meili-key
{
  config,
  lib,
  pkgs,
  secretsPath,
  ...
}: let
  meiliPort = 7700;

  # ---------------------------------------------------------------------------
  # Master-Key: agenix-Secret mit Dev-Fallback
  # ---------------------------------------------------------------------------
  # Wenn das Secret-File noch nicht im private-Repo existiert (z.B. vor dem
  # ersten Deploy), fällt die Config auf einen statischen Dev-Key zurück.
  # Der Build schlägt dadurch NICHT fehl.
  meiliSecretFile = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/edu-search/meilisearch-master-key.age";
  hasSecret = builtins.pathExists meiliSecretFile;

  devMasterKey = "edu-search-dev-key-CHANGE-ME-min-16-bytes";
  devKeyFile = pkgs.writeText "meili-dev-master-key" devMasterKey;

  # Pfad zur Key-Datei – entweder agenix-entschlüsselt oder Dev-Fallback
  # WICHTIG: config.age.secrets.meili-master-key.path NICHT in hasSecret=false
  # Branch referenzieren – sonst registriert agenix den Secret-Slot trotzdem
  # und LoadCredential zeigt auf /run/agenix/meili-master-key (existiert nicht).
  masterKeyFilePath = devKeyFile; # wird via mkIf überschrieben wenn hasSecret=true
in {
  # ---------------------------------------------------------------------------
  # Agenix Secret (nur wenn .age-Datei vorhanden)
  # ---------------------------------------------------------------------------
  age.secrets.meili-master-key = lib.mkIf hasSecret {
    file = meiliSecretFile;
    mode = "440";
    owner = "root";
    group = "root";
  };

  # ---------------------------------------------------------------------------
  # MeiliSearch Service
  # ---------------------------------------------------------------------------
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;

    # Auf allen Interfaces lauschen, damit die Web-UI (Nginx)
    # und der Caddy Reverse Proxy darauf zugreifen können.
    # Die Firewall in edu-search.nix beschränkt den Zugriff auf vlan40.
    listenAddress = "0.0.0.0";
    listenPort = meiliPort;

    # Produktionsmodus aktiviert:
    # - Erzwingt API-Key-Authentifizierung
    # - Deaktiviert die eingebaute Mini-Dashboard-UI
    # - Bessere Fehlerbehandlung
    environment = "production";

    # Master-Key für API-Authentifizierung
    # `masterKeyFile` erwartet eine Datei, die NUR den Key enthält (kein Prefix).
    # MeiliSearch leitet daraus automatisch ab:
    #   - Default Admin API Key  (voller Zugriff – für den Indexer)
    #   - Default Search API Key (nur Suche – für die Web-UI)
    # Die abgeleiteten Keys kann man abrufen via:
    #   curl -H "Authorization: Bearer $(cat <masterKeyFile>)" http://127.0.0.1:7700/keys
    masterKeyFile =
      if hasSecret
      then config.age.secrets.meili-master-key.path
      else masterKeyFilePath;
  };

  # ---------------------------------------------------------------------------
  # Key-Datei auch für andere Services zugänglich machen
  # ---------------------------------------------------------------------------
  # Nginx (webui.nix) und der Indexer (indexer.nix) brauchen den Key.
  # Wir legen eine Kopie unter /run/edu-search/meili-master-key ab,
  # die von beiden Services gelesen werden kann.
  systemd.services.edu-search-meili-key = {
    description = "Distribute MeiliSearch master key to edu-search services";
    after = ["meilisearch.service"];
    before = ["nginx.service" "edu-indexer.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "distribute-meili-key" ''
        set -euo pipefail
        mkdir -p /run/edu-search
        # Key-Datei kopieren (readable für nginx + edu-indexer)
        cp "${if hasSecret then config.age.secrets.meili-master-key.path else masterKeyFilePath}" /run/edu-search/meili-master-key
        chmod 440 /run/edu-search/meili-master-key
        chown root:users /run/edu-search/meili-master-key

        # Nginx-Snippet erzeugen: injiziert den Auth-Header beim Proxy zu MeiliSearch
        MEILI_KEY="$(cat /run/edu-search/meili-master-key)"
        echo "proxy_set_header Authorization \"Bearer $MEILI_KEY\";" \
          > /run/edu-search/meili-auth.conf
        chmod 444 /run/edu-search/meili-auth.conf
      '';
    };
  };

  # Nginx muss nach dem Key-Service starten
  systemd.services.nginx = {
    after = ["edu-search-meili-key.service"];
    wants = ["edu-search-meili-key.service"];
  };

  # ---------------------------------------------------------------------------
  # Synonyme: Typo-tolerante Suche auch für sprachliche Varianten
  # ---------------------------------------------------------------------------
  # Setzt Synonyme für den edu_documents-Index via MeiliSearch API.
  # Läuft nach dem Indexer (der den Index anlegt) und kann jederzeit
  # sicher wiederholt werden (idempotent).
  #
  # Beispiel: "if-clauses" findet auch "Bedingungssätze" und "conditional"
  systemd.services.edu-search-meili-synonyms = {
    description = "Configure MeiliSearch synonyms for edu-search";
    after = ["meilisearch.service" "edu-search-meili-key.service" "edu-indexer.service"];
    wants = ["edu-search-meili-key.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";

      ExecStart = pkgs.writeShellScript "edu-meili-synonyms" ''
        set -euo pipefail

        MEILI_URL="http://127.0.0.1:${toString meiliPort}"
        MEILI_INDEX="edu_documents"
        MEILI_KEY="$(cat /run/edu-search/meili-master-key)"

        echo "Warte auf MeiliSearch..."
        for i in $(seq 1 60); do
          if ${pkgs.curl}/bin/curl -sf "$MEILI_URL/health" > /dev/null 2>&1; then
            echo "  MeiliSearch bereit."
            break
          fi
          if [ "$i" -eq 60 ]; then
            echo "MeiliSearch nicht erreichbar nach 60s – abbruch." >&2
            exit 1
          fi
          sleep 2
        done

        echo "Setze Synonyme für Index '$MEILI_INDEX'..."
        ${pkgs.curl}/bin/curl -sf \
          -X PUT "$MEILI_URL/indexes/$MEILI_INDEX/settings/synonyms" \
          -H "Authorization: Bearer $MEILI_KEY" \
          -H "Content-Type: application/json" \
          -d '{
            "if-clauses":    ["conditional", "conditional sentences", "Bedingungssätze", "Konditionalsätze"],
            "conditional":   ["if-clauses", "conditional sentences", "Bedingungssätze"],
            "vokabeln":      ["vocabulary", "words", "Wortschatz", "Wörter", "vocabs"],
            "vocabulary":    ["vokabeln", "Wortschatz", "words"],
            "klausur":       ["test", "Klassenarbeit", "exam", "Prüfung", "Klassentest"],
            "klassenarbeit": ["klausur", "test", "exam", "Prüfung"],
            "arbeitsblatt":  ["worksheet", "exercise", "Übungsblatt", "Übung", "handout"],
            "worksheet":     ["Arbeitsblatt", "exercise", "Übungsblatt", "handout"],
            "grammatik":     ["grammar", "Sprachstruktur", "Grammatikübung"],
            "grammar":       ["Grammatik", "Sprachstruktur"],
            "lektüre":       ["reading", "Text", "Lesetext", "Leseverstehen", "lecture"],
            "reading":       ["Lektüre", "Lesetext", "Leseverstehen"],
            "präsentation":  ["presentation", "Folien", "slides", "Vortrag"],
            "presentation":  ["Präsentation", "Folien", "slides"],
            "übung":         ["exercise", "practice", "Aufgabe", "task", "worksheet"],
            "exercise":      ["Übung", "Aufgabe", "practice"],
            "present":       ["Präsens", "Simple Present", "Gegenwart"],
            "perfekt":       ["Present Perfect", "past", "Vergangenheit"],
            "passiv":        ["passive", "Passiv", "passive voice"],
            "indirekte rede": ["reported speech", "indirect speech"],
            "gerundium":     ["gerund", "Gerundive"],
            "hören":         ["listening", "Hörverstehen", "Audio"],
            "lesen":         ["reading", "Leseverstehen", "Text"],
            "schreiben":     ["writing", "Schreiben", "Aufsatz"],
            "sprechen":      ["speaking", "Sprechen", "Mündlich"]
          }' | ${pkgs.jq}/bin/jq -r '.taskUid // .message // .'

        echo "Synonyme gesetzt."
      '';
    };
  };

  # ---------------------------------------------------------------------------
  # Index-Konfiguration (Referenz)
  # ---------------------------------------------------------------------------
  # Die folgenden Einstellungen werden vom Python-Indexer beim Start
  # programmatisch gesetzt (via MeiliSearch Python Client).
  # Sie sind hier als Dokumentation aufgeführt:
  #
  # Index: "edu_documents"
  # Primary Key: "id"
  #
  # filterableAttributes: [
  #   "fach", "klasse", "typ", "niveau", "file_extension",
  #   "sprache",          → NEU: Dokumentsprache (de/en/es)
  #   "schlagwoerter",    → NEU: Array, GIN-Index
  #   "grammatik_themen", → NEU: Array, GIN-Index
  #   "hat_loesungen"     → NEU: Boolean
  # ]
  #
  # sortableAttributes: [
  #   "klasse", "filename", "last_modified",
  #   "zeitaufwand_min"   → NEU: Zeitbedarf in Minuten
  # ]
  #
  # searchableAttributes (Reihenfolge = Priorität): [
  #   "thema",            → Höchste Priorität
  #   "schlagwoerter",    → NEU: Schlagwörter
  #   "grammatik_themen", → NEU: Grammatikthemen
  #   "filename",         → Dateiname
  #   "fach",             → Fach als Suchbegriff
  #   "vokabeln_key",     → NEU: Vokabeln
  #   "content"           → Volltext (niedrigste Priorität)
  # ]
  #
  # Synonyme werden von edu-search-meili-synonyms.service gesetzt (s.o.)
  #
  # WICHTIG: "content" wird NICHT in displayedAttributes aufgenommen,
  # um die Antwortgröße klein zu halten. Der Volltext wird nur für
  # die Suche genutzt, nicht in den Ergebnissen angezeigt.

  # ---------------------------------------------------------------------------
  # Impermanence: MeiliSearch-Daten persistent machen
  # ---------------------------------------------------------------------------
  # MeiliSearch speichert seinen Index unter /var/lib/meilisearch/data.ms/
  # Obwohl der Index aus PostgreSQL + NAS rebuildet werden kann,
  # ist Persistenz sinnvoll um nach jedem Reboot nicht neu indexieren zu müssen.
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/meilisearch";
      user = "root";
      group = "root";
      mode = "0700";
    }
  ];

  # ---------------------------------------------------------------------------
  # Systemd-Service Anpassungen
  # ---------------------------------------------------------------------------
  systemd.services.meilisearch = {
    serviceConfig = {
      # Bei Fehler kurz warten bevor Restart
      RestartSec = "10s";

      # OOM-Kill-Priorität: MeiliSearch darf eher gekillt werden als PostgreSQL
      # (MeiliSearch-Index kann rebuilt werden, PostgreSQL-Daten nicht)
      OOMScoreAdjust = 200;

      # Ressourcen-Limits
      LimitNOFILE = 65536; # MeiliSearch braucht viele File-Descriptors für den Index
    };
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  # Der MeiliSearch-Port wird in edu-search.nix in der Firewall geöffnet.
  # Hier nicht nochmal öffnen um Duplikate zu vermeiden.
  # networking.firewall.allowedTCPPorts = [ meiliPort ];

  # ---------------------------------------------------------------------------
  # Nützliche Pakete für Debugging
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # jq für JSON-Formatierung bei API-Debugging
    # curl ist bereits im Base-System
    jq
  ];
}
