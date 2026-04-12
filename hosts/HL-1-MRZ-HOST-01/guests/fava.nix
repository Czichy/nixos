{
  config,
  globals,
  nodes,
  pkgs,
  secretsPath,
  hostName,
  lib,
  ...
}: let
  favaDomain = "fava.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";
  listenPort = 5000;  # Fava (nur localhost, nicht von außen direkt erreichbar)
  proxyPort = 4180;   # oauth2-proxy (nach außen, Caddy zeigt hierauf)
  ledgerFile = "/ledger/main_full.beancount";

  # Fava mit fava-dashboards Extension
  fava-with-extensions = pkgs.python3.withPackages (ps: [
    ps.fava
    ps.fava-dashboards
  ]);

  # Wrapper-Script: IBKR-Flex XMLs → Beancount-Import via ledger-eigenes Tooling
  # Voraussetzung: Python-Venv im Ledger-Repo ist initialisiert (just install)
  ibkr-import-script = pkgs.writeShellScriptBin "fava-ibkr-import" ''
    #!/usr/bin/env bash
    set -euo pipefail

    LEDGER_DIR="/ledger"
    IBKR_REPORTS="/ibkr-reports"
    YEAR=$(date +%Y)
    MONTH=$(date +%Y-%m)

    # Prüfe ob neue Reports vorhanden sind
    if ! find "$IBKR_REPORTS/$YEAR/$MONTH" -name "*.xml" -newer "$LEDGER_DIR/data/''${YEAR}_FULL.beancount" 2>/dev/null | grep -q .; then
      echo "Keine neuen IBKR-Reports gefunden, überspringe Import."
      exit 0
    fi

    echo "Starte IBKR Flex-Import für $MONTH ..."
    cd "$LEDGER_DIR"

    # Nutze das bean-report Tool oder das ledger-eigene import-Script (falls venv vorhanden)
    if [ -f venv/bin/activate ]; then
      source venv/bin/activate
      python import.py "$IBKR_REPORTS/$YEAR/$MONTH/"*.xml --output "data/''${YEAR}_FULL.beancount" || true
    else
      echo "WARN: Python venv nicht initialisiert. Führe 'just install' im Ledger-Repo aus."
      exit 1
    fi

    echo "IBKR-Import abgeschlossen."
  '';

  # FinTS Phase 2: CSV → Beancount-Konvertierung (batch, kein TAN nötig)
  #
  # Phase 1 (get_accounts.py mit TAN-Dialog) läuft IMMER auf der Workstation:
  #   just import-fints-all   → Bankverbindung, TAN-Eingabe, schreibt CSV in inbox/
  #
  # Comdirect und 1822direkt unterstützen kein pushTAN für FinTS → keine
  # Möglichkeit den TAN-Dialog zu automatisieren → Phase 1 bleibt interaktiv.
  #
  # Dieser Script repliziert den Phase-2-Teil von import_fints.sh DIREKT
  # (ohne get_accounts.py aufzurufen), da import_fints.sh kein --skip-download kennt.
  fints-phase2-script = pkgs.writeShellScriptBin "fava-fints-phase2" ''
    #!/usr/bin/env bash
    set -euo pipefail

    LEDGER_DIR="/ledger"
    FETCH_DIR="$LEDGER_DIR/fetch_fints"
    IMPORT_BASE="$LEDGER_DIR/import"
    YEAR=$(date +%Y)

    # Prüfe ob überhaupt neue Inbox-CSVs vorhanden sind
    CSV_COUNT=$(find "$IMPORT_BASE" -type f -name "*.csv" -path "*/inbox/*" | wc -l)
    if [ "$CSV_COUNT" -eq 0 ]; then
      echo "Keine neuen CSVs in inbox/, überspringe Phase 2."
      exit 0
    fi

    echo "Starte FinTS Phase 2 (CSV → Beancount) für $CSV_COUNT Dateien ..."
    cd "$LEDGER_DIR"

    if [ ! -f venv/bin/activate ]; then
      echo "WARN: Python venv nicht initialisiert (just install im Ledger-Repo ausführen)."
      exit 1
    fi

    source venv/bin/activate

    # Repliziert den CSV-Verarbeitungsteil von import_fints.sh (Zeilen 38-105),
    # OHNE den get_accounts.py Aufruf (Zeile 32) – kein TAN-Dialog, kein Netzwerk.
    while IFS= read -r -u 3 INBOX_DIR; do
      ACCOUNT_DIR="$(dirname "$INBOX_DIR")"
      ACCOUNT="$(basename "$ACCOUNT_DIR")"

      count=$(find "$INBOX_DIR" -maxdepth 1 -name "*.csv" | wc -l)
      if [ "$count" -eq 0 ]; then continue; fi

      echo "=== Konto: $ACCOUNT ($count Dateien) ==="

      JOURNAL_FILE="$ACCOUNT_DIR/3-journal/$YEAR/''${ACCOUNT}.journal"
      MAPPING_FILE="$ACCOUNT_DIR/mappings.rules"
      CONFIG_FILE="$ACCOUNT_DIR/.icsv2ledgerrc"
      ARCHIVE_DIR="$ACCOUNT_DIR/1-in/$YEAR"
      COMBINED_CSV="$INBOX_DIR/combined_temp.csv"

      mkdir -p "$(dirname "$JOURNAL_FILE")" "$ARCHIVE_DIR"

      # CSVs zusammenführen (Header nur einmal)
      ${pkgs.gawk}/bin/awk 'FNR==1 && NR!=1 {next} {print}' "$INBOX_DIR"/*.csv > "$COMBINED_CSV"

      PREV_YEAR=$((YEAR - 1))
      PREV_JOURNAL="$ACCOUNT_DIR/3-journal/$PREV_YEAR/''${ACCOUNT}.journal"
      EXISTING_ARGS=(--existing "$JOURNAL_FILE")
      [ -f "$PREV_JOURNAL" ] && EXISTING_ARGS+=(--existing "$PREV_JOURNAL")

      # --batch: keine interaktiven Abfragen, unbekannte Transaktionen landen in Expenses:Unknown
      python3 "$FETCH_DIR/csv2beancount.py" \
        -c "$CONFIG_FILE" \
        --mapping-file "$MAPPING_FILE" \
        "''${EXISTING_ARGS[@]}" \
        --skip-dupes \
        --batch \
        "$COMBINED_CSV" >> "$JOURNAL_FILE"

      EXIT_CODE=$?
      rm -f "$COMBINED_CSV"

      if [ $EXIT_CODE -eq 0 ]; then
        echo " -> OK. Archiviere $count CSVs."
        mv "$INBOX_DIR"/*.csv "$ARCHIVE_DIR/"
      else
        echo " -> FEHLER bei $ACCOUNT (Exit $EXIT_CODE). CSVs bleiben in inbox/."
      fi
    done 3< <(find "$IMPORT_BASE" -type d -name "inbox")

    echo "FinTS Phase 2 abgeschlossen."
  '';
in {
  # |----------------------------------------------------------------------| #
  microvm.mem = 512;
  microvm.vcpu = 1;

  # Virtiofs-Shares: Ledger-Repo (live, rw) und IBKR-Reports (live, ro)
  # Änderungen auf dem Host werden sofort im Gast sichtbar → Fava reloaded automatisch
  microvm.shares = [
    {
      # Ledger-Git-Repo (Syncthing-Sync mit Workstation oder Forgejo-Clone)
      source = "/shared/shares/dokumente/finanzen/ledger";
      mountPoint = "/ledger";
      tag = "ledger";
      proto = "virtiofs";
    }
    {
      # IBKR Flex-Reports (vom ibkr-flex-Gast täglich heruntergeladen)
      source = "/shared/shares/users/christian/Trading/TWS_Flex_Reports";
      mountPoint = "/ibkr-reports";
      tag = "ibkr-flex";
      proto = "virtiofs";
    }
  ];
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;
  tensorfiles.services.monitoring.node-exporter.enable = true;

  # Fava als Service registrieren (wird von kanidm.nix via globals.services.fava.domain referenziert)
  globals.services.fava.domain = favaDomain;

  # oauth2-proxy (4180) ist der einzige nach außen sichtbare Port.
  # Fava selbst (5000) lauscht nur auf localhost.
  networking.firewall.allowedTCPPorts = [proxyPort];

  # |----------------------------------------------------------------------| #
  # Innerer Caddy (HOST-02) → oauth2-proxy (nicht direkt Fava)
  # DNS-Eintrag in OPNsense Unbound: fava.czichy.com → 10.15.70.1 (Caddy DMZ)
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${favaDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-FAVA-01".ipv4}:${toString proxyPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  # Secrets: FinTS-Bankzugangsdaten (secrets.yaml aus dem Ledger-Projekt)
  # WICHTIG: Im nix-secrets-Repo muss der SSH-Host-Key dieses Gastes als
  # zusätzlicher Empfänger für diese Datei eingetragen werden:
  #   secrets/hosts/HL-1-OZ-PC-01/users/czichy/ledger/secrets.yaml.age
  age.secrets.ledger-secrets = {
    file = secretsPath + "/hosts/HL-1-OZ-PC-01/users/czichy/ledger/secrets.yaml.age";
    mode = "0600";
    owner = "fava";
  };

  age.secrets.fava-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # OAuth2-Proxy Umgebungsvariablen (OAUTH2_PROXY_CLIENT_SECRET + OAUTH2_PROXY_COOKIE_SECRET)
  age.secrets.fava-oauth2-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/fava/oauth2-env.age";
    mode = "0440";
    group = "fava";
  };

  # |----------------------------------------------------------------------| #
  users.users.fava = {
    isSystemUser = true;
    group = "fava";
  };
  users.groups.fava = {};

  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    beancount # bean-check, bean-report CLI
    fava # Fava Web UI
    git # Für manuelle git-Operationen im Ledger-Repo
    ibkr-import-script
    fints-phase2-script
  ];

  # |----------------------------------------------------------------------| #
  # Fava: Permanenter Web-Service mit File-Watching (auto-reload bei Änderungen)
  systemd.services.fava = {
    description = "Fava Beancount Web UI (Finanzen)";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      Type = "simple";
      User = "fava";
      ExecStart = "${fava-with-extensions}/bin/fava --host 0.0.0.0 --port ${toString listenPort} ${ledgerFile}";
      Restart = "always";
      RestartSec = "5s";
      # virtiofs leitet keine inotify-Events vom Host in den Gast weiter.
      # Syncthing's atomares Rename (neuer inode) würde vom inotify-Watcher
      # nie erkannt. Polling via os.stat() funktioniert korrekt auf virtiofs.
      Environment = "WATCHFILES_FORCE_POLLING=1";
      # Plugins verwenden relative Pfade (z.B. "generators/recurring_config.toml") →
      # WorkingDirectory muss /ledger sein damit Path.cwd() korrekt auflöst
      WorkingDirectory = "/ledger";
      # Sanity-Check: Startet Fava erst wenn die Ledger-Datei vorhanden ist
      ExecStartPre = "${pkgs.coreutils}/bin/test -f ${ledgerFile}";
    };
  };

  # |----------------------------------------------------------------------| #
  # Tägliche Ledger-Validierung via bean-check
  systemd.timers.bean-check = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily 07:00";
      Persistent = true;
      Unit = "bean-check.service";
    };
  };
  systemd.services.bean-check = {
    description = "Beancount Ledger-Validierung";
    serviceConfig = {
      Type = "oneshot";
      User = "fava";
      ExecStart = "${fava-with-extensions}/bin/bean-check ${ledgerFile}";
      WorkingDirectory = "/ledger";
    };
  };

  # |----------------------------------------------------------------------| #
  # IBKR Flex-Import: Mo-Fr um 00:30 (1h nach ibkr-flex-Download um 23:30)
  # Aktiviert nur wenn das Python-venv im Ledger-Repo initialisiert ist.
  systemd.timers.fava-ibkr-import = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "Mon..Fri 00:30";
      Persistent = true;
      Unit = "fava-ibkr-import.service";
    };
  };
  systemd.services.fava-ibkr-import = {
    description = "IBKR Flex-Report → Beancount Import";
    serviceConfig = {
      Type = "oneshot";
      User = "fava";
      ExecStart = "${ibkr-import-script}/bin/fava-ibkr-import";
      WorkingDirectory = "/ledger";
    };
  };

  # |----------------------------------------------------------------------| #
  # FinTS Phase 2: Reagiert auf neue CSV-Dateien im ledger/import/*/inbox/
  # Phase 1 (FinTS-Verbindung mit TAN-Dialog) MUSS auf der Workstation laufen:
  #   → just import-fints-all  (interaktiv, TAN-Eingabe im Terminal)
  #   → schreibt PKL + CSV in das virtiofs-Share
  # Dieser Watcher greift danach automatisch und konvertiert CSV → Beancount.
  systemd.paths.fava-fints-phase2 = {
    wantedBy = ["multi-user.target"];
    pathConfig = {
      # Überwacht Änderungen in allen inbox/-Ordnern der Bankkonten
      PathChanged = "/ledger/import";
      Unit = "fava-fints-phase2.service";
      # Kurze Verzögerung damit die Workstation alle Dateien fertig schreiben kann
      TriggerLimitIntervalSec = 60;
    };
  };
  systemd.services.fava-fints-phase2 = {
    description = "FinTS Phase 2: CSV → Beancount (batch, kein TAN)";
    serviceConfig = {
      Type = "oneshot";
      User = "fava";
      ExecStart = "${fints-phase2-script}/bin/fava-fints-phase2";
      WorkingDirectory = "/ledger";
      EnvironmentFile = config.age.secrets.ledger-secrets.path;
    };
  };

  # |----------------------------------------------------------------------| #
  # oauth2-proxy: Kanidm SSO-Absicherung für Fava
  # Lauscht auf 0.0.0.0:4180, proxied authentifizierte Requests an fava :5000
  # Nur Mitglieder der Gruppe "fava.access" (christian, ina) haben Zugriff.
  systemd.services.oauth2-proxy = {
    description = "oauth2-proxy (Kanidm SSO für Fava)";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "fava.service"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "simple";
      User = "fava";
      EnvironmentFile = config.age.secrets.fava-oauth2-env.path;
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.oauth2-proxy}/bin/oauth2-proxy"
        "--provider=oidc"
        "--oidc-issuer-url=https://${globals.services.kanidm.domain}/oauth2/openid/fava"
        "--client-id=fava"
        "--upstream=http://127.0.0.1:${toString listenPort}"
        "--http-address=0.0.0.0:${toString proxyPort}"
        "--redirect-url=https://${favaDomain}/oauth2/callback"
        # email-domain=* da wir sub-Claim (UUID) statt Email verwenden
        "--email-domain=*"
        # sub statt email als Identifier: Kanidm-User-UUID, kein @-Format
        "--oidc-email-claim=sub"
        "--cookie-secure=true"
        "--cookie-name=_fava_oauth2"
        # SameSite=none: notwendig damit der CSRF-Cookie beim OAuth-Callback zurückgeschickt
        # wird. Firefox blockiert SameSite=Lax cookies in no-cors Redirect-Chains (favicon etc.)
        "--cookie-samesite=none"
        # reverse-proxy: X-Forwarded-* Headers von Caddy vertrauen (Host, Proto, For)
        "--reverse-proxy=true"
        "--skip-provider-button=true"
        "--silence-ping-logging=true"
        "--code-challenge-method=S256"
        # Statische Assets direkt durchlassen (kein OAuth-Loop für favicon etc.)
        "--skip-auth-regex=^/(favicon\\.ico|robots\\.txt)$"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
