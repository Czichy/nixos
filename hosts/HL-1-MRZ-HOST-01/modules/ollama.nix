# Ollama LLM Service – nativ auf HOST-01 mit CUDA-Beschleunigung
#
# Ollama läuft DIREKT auf dem Host (nicht in einer MicroVM), weil:
# - microvm.nix unterstützt kein GPU-Passthrough (kein PCI-Passthrough)
# - NVIDIA GTX 1660 SUPER (6GB VRAM) erfordert nativen CUDA-Zugriff
# - Kein VM-Overhead → volle GPU-Leistung für LLM-Inference
#
# Wird genutzt von:
# - edu-search MicroVM (Klassifikation von Unterrichtsmaterialien)
# - Open-WebUI MicroVM (Chat-Interface, optional)
# - Alle Services im vlan40 können die API erreichen
#
# Modell-Empfehlungen für 6GB VRAM:
# - mistral:7b    (~4.1GB VRAM) ← Empfohlen: gut für strukturierte JSON-Extraktion
# - llama3.1:8b   (~4.7GB VRAM) ← Alternative: besser auf Deutsch
# - gemma2:2b     (~1.5GB VRAM) ← Schnell, aber weniger genau
# - NICHT gemma2:9b oder größer (übersteigt 6GB VRAM!)
{
  config,
  globals,
  pkgs,
  ...
}: {
  # ---------------------------------------------------------------------------
  # Globals: Ollama als Service registrieren
  # ---------------------------------------------------------------------------
  # Damit andere VMs (edu-search, open-webui, n8n, etc.) den Ollama-Service
  # sauber über globals referenzieren können:
  #   globals.services.ollama.domain
  #   globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4 + :11434
  globals.services.ollama = {
    domain = "ollama.${globals.domains.me}";
    homepage = {
      enable = true;
      name = "Ollama";
      icon = "sh-ollama";
      description = "LLM-Inference (GPU/CUDA) – mistral:7b, llama3.1:8b";
      category = "Infrastructure";
      priority = 40;
      abbr = "LLM";
    };
  };

  # Monitoring: Ollama Health-Check (GET / → "Ollama is running")
  # Erreichbar für alle VMs im vlan40 über die HOST-01 IP.
  globals.monitoring.http.ollama = {
    url = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:${toString config.services.ollama.port}";
    expectedBodyRegex = "Ollama is running";
    network = "vlan40";
  };

  # ---------------------------------------------------------------------------
  # Ollama Service
  # ---------------------------------------------------------------------------
  services.ollama = {
    enable = true;

    # Auf allen Interfaces lauschen – Firewall beschränkt den Zugriff
    host = "0.0.0.0";
    port = 11434;

    # CUDA-Beschleunigung via NVIDIA GPU aktivieren
    # Voraussetzung: gpu.nix muss die NVIDIA-Treiber laden
    package = pkgs.ollama-cuda;

    # Modelle beim Start automatisch vorhalten (optional)
    # Auskommentieren um beim ersten Deploy Bandbreite zu sparen,
    # dann manuell: ollama pull mistral:7b
    # loadModels = [ "mistral:7b" ];

    # Umgebungsvariablen für Ollama
    environmentVariables = {
      # Maximale Anzahl paralleler Anfragen (default: 1)
      # Für den Indexer reicht 1, bei mehreren Nutzern erhöhen
      OLLAMA_NUM_PARALLEL = "2";

      # Modell nach Inaktivität im VRAM behalten (in Minuten)
      # Bei 6GB VRAM und einem 7B-Modell passt genau eins
      OLLAMA_KEEP_ALIVE = "30m";

      # Keine Telemetrie
      DO_NOT_TRACK = "1";
    };
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  # Ollama-API nur aus dem Server-VLAN (vlan40) erreichbar machen.
  # Die MicroVMs (edu-search, open-webui) sind alle im vlan40.
  networking.firewall.allowedTCPPorts = [config.services.ollama.port];

  # ---------------------------------------------------------------------------
  # Impermanence
  # ---------------------------------------------------------------------------
  # Ollama speichert heruntergeladene Modelle unter /var/lib/private/ollama.
  # Diese sollen Reboots überleben (Modelle sind mehrere GB groß).
  # Wir nutzen /state statt /persist, weil Modelle jederzeit via
  # `ollama pull` wiederhergestellt werden können – kein Backup nötig.
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/ollama";
      mode = "0700";
    }
  ];

  # ---------------------------------------------------------------------------
  # Systemd-Service Hardening
  # ---------------------------------------------------------------------------
  # Ollama's systemd-Service bekommt automatisch DynamicUser + StateDirectory
  # via das NixOS-Modul. Wir fügen nur den Restart-Delay hinzu.
  systemd.services.ollama = {
    serviceConfig = {
      # Bei Fehler 30s warten bevor Restart (z.B. GPU-Treiber noch nicht bereit)
      RestartSec = "30";
    };
  };

  # ---------------------------------------------------------------------------
  # Oneshot-Service: Modell nach Deploy/Reboot vorladen
  # ---------------------------------------------------------------------------
  # Dieser Service pullt das Klassifikationsmodell falls es noch nicht vorhanden ist.
  # Läuft nur einmal nach dem Boot und blockiert nicht den Start anderer Services.
  systemd.services.ollama-pull-models = {
    description = "Pull default Ollama models if not present";
    after = ["ollama.service"];
    requires = ["ollama.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Warte bis Ollama wirklich bereit ist
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = let
        pullScript = pkgs.writeShellScript "ollama-pull-models" ''
          set -euo pipefail
          export OLLAMA_HOST="http://127.0.0.1:${toString config.services.ollama.port}"

          # Prüfe ob Ollama erreichbar ist
          for i in $(seq 1 30); do
            if ${pkgs.curl}/bin/curl -sf "$OLLAMA_HOST/api/tags" > /dev/null 2>&1; then
              break
            fi
            if [ "$i" -eq 30 ]; then
              echo "Ollama nicht erreichbar nach 60s – breche ab." >&2
              exit 1
            fi
            echo "Warte auf Ollama... ($i/30)"
            sleep 2
          done

          # Modell pullen falls noch nicht vorhanden
          # WICHTIG: Wir nutzen die HTTP-API statt 'ollama pull', weil das
          # CLI-Binary aus pkgs.ollama nicht mit dem CUDA-Build (pkgs.ollama-cuda)
          # kompatibel ist und einen Panic wirft (envconfig.AsMap).
          MODELS=$(${pkgs.curl}/bin/curl -sf "$OLLAMA_HOST/api/tags" | ${pkgs.jq}/bin/jq -r '.models[].name // empty')

          if ! echo "$MODELS" | grep -q "^mistral:7b"; then
            echo "Pulling mistral:7b via HTTP API ..."
            ${pkgs.curl}/bin/curl -sf -X POST "$OLLAMA_HOST/api/pull" \
              -H "Content-Type: application/json" \
              -d '{"name": "mistral:7b", "stream": false}' \
              --max-time 1800
            echo ""
            echo "mistral:7b erfolgreich geladen."
          else
            echo "mistral:7b bereits vorhanden."
          fi
        '';
      in "${pullScript}";

      # Nicht den Boot blockieren wenn das Pullen fehlschlägt
      Restart = "no";
      TimeoutStartSec = "30min";
    };

    # Nur bei Netzwerkverfügbarkeit (Modell-Download braucht Internet)
    wants = ["network-online.target"];
  };

  # ---------------------------------------------------------------------------
  # Monitoring / Health Check
  # ---------------------------------------------------------------------------
  # Ollama Health-Endpoint: GET / → "Ollama is running"
  # Monitoring ist oben via globals.monitoring.http.ollama konfiguriert.
  # Erreichbar für alle VMs im vlan40 unter:
  #   http://<HOST-01-IP>:11434
}
