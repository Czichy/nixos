{
  config,
  globals,
  lib,
  pkgs,
  secretsPath,
  ...
}:
let
  victoriaDomain = "metrics.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";

  # Port auf dem VictoriaMetrics lauscht
  vmPort = 8428;
  nodePort = 9100;

  # SeekingEdge App-Host (dein Dev-PC oder der Host wo die App laeuft)
  seekingEdgeHost = globals.net.vlan40.hosts."HL-1-OZ-PC-01".ipv4;

  # Hilfsfunktion: Node-Exporter-Scrape-Target erzeugen
  mkNodeTarget = ip: instance: {
    targets = [ "${ip}:${toString nodePort}" ];
    labels = { inherit instance; };
  };
in
{
  networking.hostName = "HL-3-RZ-METRICS-01";
  tensorfiles.services.monitoring.node-exporter.enable = true;

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      vmPort # VictoriaMetrics HTTP API
      8089 # OpenTelemetry OTLP/HTTP (optional, fuer remote write)
    ];
  };
  # |----------------------------------------------------------------------| #

  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${victoriaDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                tls_insecure_skip_verify
            	tls_server_name ${victoriaDomain}
            }
            header_up Host {http.request.host}
        }
        import czichy_headers
      '';
    };
  };

  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${victoriaDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-METRICS-01".ipv4}:${toString vmPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  globals.services.victoria = {
    domain = victoriaDomain;
    homepage = {
      enable = true;
      name = "VictoriaMetrics";
      icon = "sh-victoria";
      description = "High-performance time-series database for SeekingEdge trading metrics";
      category = "Monitoring & Observability";
      priority = 30;
      abbr = "VM";
    };
  };

  globals.monitoring.http.victoria = {
    url = "https://${victoriaDomain}/health";
    expectedBodyRegex = "OK";
    network = "internet";
  };

  # |----------------------------------------------------------------------| #
  # | SYSTEM PACKAGES                                                      |
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    victoriametrics # CLI tools (vmctl, etc.)
    curl # Health checks
  ];

  # |----------------------------------------------------------------------| #
  # | USER & GROUP (static, not DynamicUser - required for MicroVM)        |
  # |----------------------------------------------------------------------| #
  users.users.victoriametrics = {
    isSystemUser = true;
    group = "victoriametrics";
    home = "/var/lib/victoriametrics";
  };
  users.groups.victoriametrics = { };

  # Override DynamicUser from upstream module - incompatible with
  # impermanence bind-mounts (causes "Device or resource busy")
  systemd.services.victoriametrics.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "victoriametrics";
    Group = "victoriametrics";
    StateDirectory = lib.mkForce "";
  };

  # |----------------------------------------------------------------------| #
  # | PERSISTENCE (impermanence)                                           |
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/victoriametrics";
      user = "victoriametrics";
      group = "victoriametrics";
      mode = "0700";
    }
  ];

  # |----------------------------------------------------------------------| #
  # | VICTORIAMETRICS                                                      |
  # |----------------------------------------------------------------------| #
  services.victoriametrics = {
    enable = true;
    # 12 Monate Retention - fuer Trading-Metriken voellig ausreichend
    retentionPeriod = "12";
    # Auf allen Interfaces lauschen, damit andere MicroVMs (Grafana) zugreifen koennen
    listenAddress = "0.0.0.0:${toString vmPort}";

    prometheusConfig = {
      global = {
        scrape_interval = "15s";
      };

      scrape_configs = [
        # --- SeekingEdge Trading Platform ---
        {
          job_name = "seeking-edge";
          scrape_interval = "10s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "${seekingEdgeHost}:9091" ];
              labels = {
                instance = "seeking-edge";
                environment = "production";
              };
            }
          ];
        }

        # --- SeekingEdge Backtest Runner ---
        {
          job_name = "seeking-edge-backtest";
          scrape_interval = "10s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "${seekingEdgeHost}:9092" ];
              labels = {
                instance = "seeking-edge-backtest";
                environment = "backtest";
              };
            }
          ];
        }

        # --- VictoriaMetrics Self-Monitoring ---
        {
          job_name = "victoriametrics";
          scrape_interval = "15s";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString vmPort}" ];
              labels = {
                instance = "victoriametrics";
              };
            }
          ];
        }

        # --- Node Exporter: System-Metriken aller Hosts ---
        # CPU, RAM, Disk, Netzwerk fuer Hypervisoren und key MicroVMs
        {
          job_name = "node";
          scrape_interval = "30s";
          static_configs = [
            # Hypervisoren
            (mkNodeTarget globals.net.vlan40.hosts."HL-1-MRZ-HOST-01".ipv4 "host-01")
            (mkNodeTarget globals.net.vlan40.hosts."HL-1-MRZ-HOST-02".ipv4 "host-02")
            (mkNodeTarget globals.net.vlan100.hosts."HL-1-MRZ-HOST-03".ipv4 "host-03")
            # Monitoring Stack
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-METRICS-01".ipv4 "victoria")
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-GRAFANA-01".ipv4 "grafana")
            # Auth & Git
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-AUTH-01".ipv4 "kanidm")
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-GIT-01".ipv4 "forgejo")
            # Apps
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-N8N-01".ipv4 "n8n")
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-KARA-01".ipv4 "karakeep")
            # Home
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-HASS-01".ipv4 "hass")
            (mkNodeTarget globals.net.vlan40.hosts."HL-3-RZ-HOME-01".ipv4 "homepage")
          ];
        }
      ];
    };

    extraOptions = [
      # Erlaube groessere Queries (noetig fuer Grafana Dashboard mit vielen Panels)
      "-search.maxQueryLen=16384"
      # Deduplication Window (bei mehrfachem Scrape gleicher Daten)
      "-dedup.minScrapeInterval=15s"
      # Memory-Limit fuer die MicroVM (konservativ)
      "-memory.allowedPercent=60"
    ];
  };
}
