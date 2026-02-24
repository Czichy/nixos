# Open-WebUI MicroVM – Chat-Interface für Ollama
#
# REFACTORED: Ollama wurde aus dieser MicroVM entfernt und läuft jetzt
# nativ auf HOST-01 mit GPU-Beschleunigung (CUDA, GTX 1660 SUPER).
# Siehe: hosts/HL-1-MRZ-HOST-01/modules/ollama.nix
#
# Diese MicroVM enthält nur noch Open-WebUI als Chat-Frontend.
# Open-WebUI greift via HTTP auf den nativen Ollama-Service zu:
#   http://10.15.40.10:11434 (HOST-01, vlan40)
#
# Ressourcen-Ersparnis durch Refactoring:
#   Vorher: 16GB RAM, 20 vCPUs (Ollama CPU-only + Open-WebUI)
#   Nachher: 2GB RAM, 2 vCPUs (nur Open-WebUI)
#   → 14GB RAM und 18 vCPUs für andere MicroVMs frei
{
  config,
  globals,
  ...
}: let
  openWebuiDomain = "chat.${globals.domains.me}";

  # Ollama läuft nativ auf HOST-01 (GPU-beschleunigt)
  ollamaUrl = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";
in {
  # ---------------------------------------------------------------------------
  # MicroVM-Ressourcen (drastisch reduziert nach Ollama-Entfernung)
  # ---------------------------------------------------------------------------
  microvm.mem = 1024 * 2; # 2 GB statt 16 GB – Open-WebUI braucht ~500MB
  microvm.vcpu = 2; # 2 vCPUs statt 20 – Open-WebUI ist nicht CPU-intensiv

  # ---------------------------------------------------------------------------
  # Wireguard / Reverse Proxy
  # ---------------------------------------------------------------------------
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.open-webui.port];
  };

  # ---------------------------------------------------------------------------
  # Firewall
  # ---------------------------------------------------------------------------
  # Ollama-Port wird NICHT mehr geöffnet – Ollama läuft nicht mehr in dieser VM.
  # Nur Open-WebUI-Port ist nötig (wird via wireguard.proxy-sentinel geregelt).
  networking.firewall.allowedTCPPorts = [config.services.open-webui.port];

  # ---------------------------------------------------------------------------
  # Impermanence
  # ---------------------------------------------------------------------------
  environment.persistence."/state".directories = [
    # Ollama-Verzeichnis ENTFERNT – Ollama läuft nativ auf HOST-01
    # {
    #   directory = "/var/lib/private/ollama";
    #   mode = "0700";
    # }
    {
      directory = "/var/lib/private/open-webui";
      mode = "0700";
    }
  ];

  # ---------------------------------------------------------------------------
  # Ollama: ENTFERNT – läuft nativ auf HOST-01 mit CUDA
  # ---------------------------------------------------------------------------
  # Vorher:
  #   services.ollama = {
  #     enable = true;
  #     host = "0.0.0.0";
  #     port = 11434;
  #   };
  #
  # Jetzt: Ollama ist ein nativer Service auf HOST-01
  # Konfiguration: hosts/HL-1-MRZ-HOST-01/modules/ollama.nix
  # Erreichbar unter: http://10.15.40.10:11434 (vlan40)

  # ---------------------------------------------------------------------------
  # Open-WebUI: Chat-Frontend für Ollama
  # ---------------------------------------------------------------------------
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 11222;
    environment = {
      # Telemetrie deaktivieren
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      # Community-Features deaktivieren
      ENABLE_COMMUNITY_SHARING = "False";
      ENABLE_ADMIN_EXPORT = "False";

      # Ollama-Backend: zeigt auf den nativen Service auf HOST-01 (GPU)
      # Vorher: "http://localhost:11434" (lokaler CPU-only Ollama in der VM)
      # Jetzt: HOST-01 nativ mit CUDA-Beschleunigung → deutlich schneller
      OLLAMA_BASE_URL = ollamaUrl;

      # Huggingface-Cache für Open-WebUI Modelle
      TRANSFORMERS_CACHE = "/var/lib/open-webui/.cache/huggingface";

      # Authentifizierung über oauth2-proxy (Header-basiert)
      WEBUI_AUTH = "False";
      ENABLE_SIGNUP = "False";
      WEBUI_AUTH_TRUSTED_EMAIL_HEADER = "X-Email";
      DEFAULT_USER_ROLE = "user";
    };
  };

  # ---------------------------------------------------------------------------
  # Globals: Service-Registrierung
  # ---------------------------------------------------------------------------
  globals.services.open-webui.domain = openWebuiDomain;

  # Monitoring: Ollama Health-Check über den nativen Service auf HOST-01
  # (nicht mehr lokal in dieser VM)
  globals.monitoring.http.ollama = {
    url = ollamaUrl;
    expectedBodyRegex = "Ollama is running";
    network = "vlan40";
  };

  # ---------------------------------------------------------------------------
  # Reverse Proxy: Nginx auf Sentinel
  # ---------------------------------------------------------------------------
  nodes.sentinel = {
    services.nginx = {
      upstreams.open-webui = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.open-webui.port}" = {};
        extraConfig = ''
          zone open-webui 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Open WebUI";
        };
      };
      virtualHosts.${openWebuiDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2 = {
          enable = true;
          allowedGroups = ["access_openwebui"];
          X-Email = "\${upstream_http_x_auth_request_preferred_username}@${globals.domains.personal}";
        };
        extraConfig = ''
          client_max_body_size 128M;
        '';
        locations."/" = {
          proxyPass = "http://open-webui";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
      };
    };
  };
}
