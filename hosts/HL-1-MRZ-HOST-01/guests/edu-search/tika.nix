# Apache Tika als HTTP-Server für Textextraktion
#
# Tika extrahiert Klartext aus praktisch jedem Dateiformat:
# DOCX, PPTX, PDF, ODT, ODS, XLSX, RTF, HTML, TXT, EPUB,
# MP3/MP4/M4A (Metadaten), und viele mehr.
#
# Da `pkgs.apacheTika` in nixpkgs nicht als eigenständiges Paket existiert,
# wird das offizielle Apache Tika Server JAR via `fetchurl` bezogen und
# mit einer headless JDK-Runtime als systemd-Service betrieben.
#
# Der Server lauscht NUR auf 127.0.0.1 (MicroVM-intern).
# Der Python-Indexer greift via HTTP auf die Tika-API zu:
#   PUT /tika         → Plaintext-Extraktion
#   PUT /meta         → Metadaten als JSON
#   GET /tika/form    → Multipart-Upload
#
# Tika ist STATELESS – kein persistenter Zustand, kein Backup nötig.
{
  lib,
  pkgs,
  ...
}: let
  tikaPort = 9998;
  tikaHost = "127.0.0.1";
  tikaVersion = "3.1.0";

  # -------------------------------------------------------------------------
  # Apache Tika Server JAR direkt von Apache herunterladen
  # -------------------------------------------------------------------------
  # Den SHA256-Hash beim ersten Build ermitteln:
  #   nix-prefetch-url https://archive.apache.org/dist/tika/${tikaVersion}/tika-server-standard-${tikaVersion}.jar
  #
  # Wir nutzen archive.apache.org statt dlcdn.apache.org, weil der
  # Archive-Mirror stabile URLs hat (dlcdn kann sich ändern).
  tika-server-jar = pkgs.fetchurl {
    url = "https://archive.apache.org/dist/tika/${tikaVersion}/tika-server-standard-${tikaVersion}.jar";
    hash = "sha256-npdfFKvABcW+w4SUSTtqvPpUltc7KF+3jDs9akrhV6Y=";
  };

  # JDK für Tika (headless, kein GUI nötig)
  jdk = pkgs.jdk21_headless;
in {
  # -------------------------------------------------------------------------
  # Apache Tika systemd Service
  # -------------------------------------------------------------------------
  systemd.services.tika-server = {
    description = "Apache Tika Server – Text extraction from documents";
    documentation = ["https://tika.apache.org/"];

    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "15s";

      # Dynamischer User (kein eigener Eintrag in /etc/passwd nötig)
      DynamicUser = true;
      StateDirectory = "tika";
      CacheDirectory = "tika";

      # Tika's WatchDog forks a child process and calls "java" by name,
      # so the JDK bin directory must be in PATH.
      Environment = ["PATH=${jdk}/bin:/run/current-system/sw/bin"];

      ExecStart = lib.concatStringsSep " " [
        "${jdk}/bin/java"
        # JVM-Heap: 512MB reichen für Einzeldatei-Extraktion.
        # Bei sehr großen PDFs (>100MB) ggf. auf 1024m erhöhen.
        "-Xmx512m"
        "-Xms128m"
        # Tika-spezifische JVM-Flags
        "-Duser.home=/var/lib/tika"
        "-Djava.io.tmpdir=/var/cache/tika"
        # Kein GUI
        "-Djava.awt.headless=true"
        # JAR starten
        "-jar"
        "${tika-server-jar}"
        # Nur lokal lauschen (MicroVM-intern)
        "--host"
        "${tikaHost}"
        "--port"
        "${toString tikaPort}"
      ];

      # Warte bis der HTTP-Server bereit ist
      ExecStartPost = let
        healthCheck = pkgs.writeShellScript "tika-healthcheck" ''
          for i in $(seq 1 30); do
            if ${pkgs.curl}/bin/curl -sf "http://${tikaHost}:${toString tikaPort}/tika" > /dev/null 2>&1; then
              echo "Tika Server ist bereit (Port ${toString tikaPort})"
              exit 0
            fi
            sleep 1
          done
          echo "WARNUNG: Tika Server antwortet nicht nach 30s" >&2
          exit 0  # Nicht den Start blockieren
        '';
      in "${healthCheck}";

      # -----------------------------------------------------------------------
      # Sicherheits-Härtung
      # -----------------------------------------------------------------------
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = false; # JVM braucht JIT
      SystemCallArchitectures = "native";

      # Ressourcen-Limits
      LimitNOFILE = 4096;
      # OOM-Kill-Priorität: Tika darf eher gekillt werden als PostgreSQL
      OOMScoreAdjust = 300;
    };
  };

  # -------------------------------------------------------------------------
  # Firewall: Tika ist nur lokal erreichbar, kein offener Port nötig
  # -------------------------------------------------------------------------
  # tikaPort wird NICHT in networking.firewall.allowedTCPPorts aufgenommen,
  # da Tika nur auf 127.0.0.1 lauscht.

  # -------------------------------------------------------------------------
  # HINWEIS: Tika ist stateless. Kein Persistenz-Eintrag,
  # kein Backup, kein Impermanence-Eintrag nötig.
  # -------------------------------------------------------------------------
}
