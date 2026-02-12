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

  # SeekingEdge App-Host (dein Dev-PC oder der Host wo die App laeuft)
  seekingEdgeHost = globals.net.vlan40.hosts."HL-1-OZ-PC-01".ipv4;
in {
  networking.hostName = "HL-3-RZ-METRICS-01";

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      vmPort    # VictoriaMetrics HTTP API
      8089      # OpenTelemetry OTLP/HTTP (optional, fuer remote write)
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
    victoriametrics  # CLI tools (vmctl, etc.)
    curl             # Health checks
  ];

  # |----------------------------------------------------------------------| #
  # | USER & GROUP (static, not DynamicUser - required for MicroVM)        |
  # |----------------------------------------------------------------------| #
  users.users.victoriametrics = {
    isSystemUser = true;
    group = "victoriametrics";
    home = "/var/lib/victoriametrics";
  };
  users.groups.victoriametrics = {};

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
        # Die Rust-App exportiert Prometheus-Metriken auf Port 9091
        # via se_observability crate (opentelemetry-prometheus exporter)
        {
          job_name = "seeking-edge";
          scrape_interval = "10s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = ["${seekingEdgeHost}:9091"];
              labels = {
                instance = "seeking-edge";
                environment = "production";
              };
            }
          ];
        }

        # --- SeekingEdge Backtest Runner ---
        # Gleiche App, aber im Backtest-Modus (anderer Port moeglich)
        {
          job_name = "seeking-edge-backtest";
          scrape_interval = "10s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = ["${seekingEdgeHost}:9092"];
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
              targets = ["127.0.0.1:${toString vmPort}"];
              labels = {
                instance = "victoriametrics";
              };
            }
          ];
        }

        # --- Node Exporter (Host-Metriken der MicroVM) ---
        {
          job_name = "node";
          scrape_interval = "30s";
          static_configs = [
            {
              targets = ["127.0.0.1:9100"];
              labels = {
                instance = "metrics-vm";
              };
            }
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

  # |----------------------------------------------------------------------| #
  # | NODE EXPORTER (optional - Host-Metriken)                             |
  # |----------------------------------------------------------------------| #
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [
      "cpu"
      "meminfo"
      "diskstats"
      "filesystem"
      "netdev"
      "loadavg"
    ];
  };
}
