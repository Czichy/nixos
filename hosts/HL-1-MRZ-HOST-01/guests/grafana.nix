{
  config,
  globals,
  secretsPath,
  nodes,
  pkgs,
  ...
}: let
  grafanaDomain = "grafana.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";
in {
  networking.hostName = "HL-3-RZ-GRAFANA-01";

  networking.firewall = {
    allowedTCPPorts = [config.services.grafana.settings.server.http_port];
  };

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${grafanaDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                # Da der innere Caddy ein eigenes Zertifikat ausstellt,
                # muss die Überprüfung auf dem äußeren Caddy übersprungen werden.
                # Dies ist ein Workaround, wenn die Zertifikatskette nicht vertrauenswürdig ist.
                tls_insecure_skip_verify
                # tls_server_name stellt sicher, dass der Hostname für die TLS-Handshake übermittelt wird.
            	tls_server_name ${grafanaDomain}
            }
        }

        # tls ${certloc}/fullchain.pem ${certloc}/key.pem {
        #   protocols tls1.3
        # }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${grafanaDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-GRAFANA-01".ipv4}:${toString config.services.grafana.settings.server.http_port}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  # |----------------------------------------------------------------------| #
  age.secrets.grafana-admin-password = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/grafana/grafana-secret-key.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-secret-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/grafana/grafana-secret-key.age";
    mode = "440";
    group = "grafana";
  };

  # age.secrets.grafana-loki-basic-auth-password = {
  #   generator.script = "alnum";
  #   mode = "440";
  #   group = "grafana";
  # };

  age.secrets.grafana-influxdb-token-machines = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/smart-home-token.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-token-home = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/home_assistant-token.age";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-user-telegraf-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/telegraf-token.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-user-smart-home-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/smart-home-token.age";
    mode = "440";
    group = "grafana";
  };

  age.secrets.grafana-influxdb-user-home_assistant-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/home_assistant-token.age";
    mode = "440";
    group = "grafana";
  };
  # HL-3-RZ-INFLUX-01
  #   nodes.sire-influxdb = {
  #     # Mirror the original secret on the influx host
  #     age.secrets."grafana-influxdb-token-machines-${config.node.name}" = {
  #       inherit (config.age.secrets.grafana-influxdb-token-machines) rekeyFile;
  #       mode = "440";
  #       group = "influxdb2";
  #     };

  #     services.influxdb2.provision.organizations.machines.auths."grafana machines:telegraf (${config.node.name})" = {
  #       readBuckets = ["telegraf"];
  #       writeBuckets = ["telegraf"];
  #       tokenFile =
  #         nodes.sire-influxdb.config.age.secrets."grafana-influxdb-token-machines-${config.node.name}".path;
  #     };
  #   };

  globals.services.grafana = {
    domain = grafanaDomain;
    homepage = {
      enable = true;
      name = "Grafana";
      icon = "sh-grafana";
      description = "Interactive metrics visualization, dashboards & alerting platform";
      category = "Monitoring & Observability";
      priority = 10;
      abbr = "GF";
      widget = {
        type = "grafana";
        url = "https://${grafanaDomain}";
        username = "czichy";
        password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}";
      };
    };
  };
  globals.monitoring.http.grafana = {
    url = "https://${grafanaDomain}";
    expectedBodyRegex = "Grafana";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = config.services.grafana.dataDir;
      user = "grafana";
      group = "grafana";
      mode = "0700";
    }
  ];

  services.grafana = {
    enable = true;
    settings = {
      analytics.reporting_enabled = false;
      users.allow_sign_up = false;

      # Unified Alerting
      "unified_alerting".enabled = true;
      alerting.enabled = false;

      server = {
        domain = grafanaDomain;
        root_url = "https://${grafanaDomain}";
        enforce_domain = true;
        enable_gzip = true;
        http_addr = "0.0.0.0";
        http_port = 3001;
      };

      security = {
        disable_initial_admin_creation = true;
        admin_user = "czichy";
        admin_password = "$toString ${config.age.secrets.grafana-admin-password.path}";
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
        cookie_secure = true;
        disable_gravatar = true;
        hide_version = true;
      };

    };

    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          # uid = "victoria-metrics";
          type = "prometheus";
          access = "proxy";
          url = "http://${globals.net.vlan40.hosts."HL-3-RZ-METRICS-01".ipv4}:8428";
          isDefault = true;
          editable = true;
          jsonData = {
            timeInterval = "10s";
            httpMethod = "POST";
          };
        }
        {
          name = "InfluxDB (machines)";
          # uid = "influxdb-machines";
          type = "influxdb";
          access = "proxy";
          url = "https://${globals.services.influxdb.domain}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-user-telegraf-token.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "machines";
          jsonData.defaultBucket = "telegraf";
        }
        {
          name = "InfluxDB (smart_home)";
          # uid = "influxdb-smart-home";
          type = "influxdb";
          access = "proxy";
          url = "https://${globals.services.influxdb.domain}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-user-smart-home-token.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "home";
          jsonData.defaultBucket = "smart-home";
        }
        {
          name = "InfluxDB (home_assistant)";
          # uid = "influxdb-home-assistant";
          type = "influxdb";
          access = "proxy";
          url = "https://${globals.services.influxdb.domain}";
          orgId = 1;
          secureJsonData.token = "$__file{${config.age.secrets.grafana-influxdb-user-home_assistant-token.path}}";
          jsonData.version = "Flux";
          jsonData.organization = "home";
          jsonData.defaultBucket = "home_assistant";
        }
      ];
      dashboards.settings.providers = [
        {
          name = "SeekingEdge";
          options.path = pkgs.stdenv.mkDerivation {
            name = "grafana-dashboards";
            src = ./grafana-dashboards;
            installPhase = ''
              mkdir -p $out/
              install -D -m644 $src/*.json $out/
            '';
          };
        }
      ];

      # --- SeekingEdge Alerting ---
      alerting.contactPoints.settings = {
        apiVersion = 1;
        contactPoints = [
          {
            orgId = 1;
            name = "ntfy-phone";
            receivers = [
              {
                uid = "ntfy-seeking-edge";
                type = "webhook";
                disableResolveMessage = false;
                settings = {
                  url = "https://push.czichy.com/seeking-edge";
                  httpMethod = "POST";
                  maxAlerts = "5";
                  authorization_scheme = "Basic";
                  authorization_credentials = "";
                };
              }
            ];
          }
        ];
      };

      alerting.policies.settings = {
        apiVersion = 1;
        policies = [
          {
            orgId = 1;
            receiver = "ntfy-phone";
            group_by = ["alertname"];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
            routes = [
              {
                receiver = "ntfy-phone";
                group_wait = "10s";
                repeat_interval = "1h";
                object_matchers = [
                  ["severity" "=" "critical"]
                ];
              }
              {
                receiver = "ntfy-phone";
                group_wait = "30s";
                repeat_interval = "4h";
                mute_time_intervals = ["outside-market-hours"];
                object_matchers = [
                  ["severity" "=" "warning"]
                ];
              }
            ];
          }
        ];
      };

      alerting.muteTimings.settings = {
        apiVersion = 1;
        muteTimes = [
          {
            orgId = 1;
            name = "outside-market-hours";
            intervals = [
              {
                weekdays = ["saturday" "sunday"];
              }
              {
                weekdays = ["monday" "tuesday" "wednesday" "thursday" "friday"];
                times = [{ start = "00:00"; end = "14:30"; }];
              }
              {
                weekdays = ["monday" "tuesday" "wednesday" "thursday" "friday"];
                times = [{ start = "21:00"; end = "24:00"; }];
              }
            ];
          }
        ];
      };

      alerting.rules.settings = {
        apiVersion = 1;
        groups = [
          {
            orgId = 1;
            name = "trading-health";
            folder = "SeekingEdge Alerts";
            interval = "60s";
            rules = [
              {
                uid = "se-system-errors";
                title = "System Errors Detected";
                condition = "C";
                for = "1m";
                noDataState = "OK";
                execErrState = "Alerting";
                labels = { severity = "critical"; };
                annotations = { summary = "System errors detected"; };
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = { from = 300; to = 0; };
                    datasourceUid = "victoria-metrics";
                    model = {
                      refId = "A";
                      expr = "sum(rate(system_errors_total[5m]))";
                    };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = { type = "reduce"; refId = "B"; expression = "A"; reducer = "last"; };
                  }
                  {
                    refId = "C";
                    datasourceUid = "__expr__";
                    model = { type = "threshold"; refId = "C"; expression = "B"; conditions = [{ evaluator = { type = "gt"; params = [0]; }; }]; };
                  }
                ];
              }
              {
                uid = "se-trading-stopped";
                title = "Trading Stopped - No Orders";
                condition = "C";
                for = "10m";
                noDataState = "Alerting";
                execErrState = "Alerting";
                labels = { severity = "warning"; };
                annotations = { summary = "No orders created in the last 10 minutes"; };
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = { from = 600; to = 0; };
                    datasourceUid = "victoria-metrics";
                    model = { refId = "A"; expr = "sum(rate(orders_created_total[10m]))"; };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = { type = "reduce"; refId = "B"; expression = "A"; reducer = "last"; };
                  }
                  {
                    refId = "C";
                    datasourceUid = "__expr__";
                    model = { type = "threshold"; refId = "C"; expression = "B"; conditions = [{ evaluator = { type = "lt"; params = [0.001]; }; }]; };
                  }
                ];
              }
              {
                uid = "se-latency-spike";
                title = "Signal-to-Order Latency Spike";
                condition = "C";
                for = "2m";
                noDataState = "OK";
                execErrState = "Alerting";
                labels = { severity = "warning"; };
                annotations = { summary = "Signal-to-order latency p95 exceeded 200ms"; };
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = { from = 300; to = 0; };
                    datasourceUid = "victoria-metrics";
                    model = { refId = "A"; expr = "histogram_quantile(0.95, rate(latency_signal_to_order_ms_bucket[5m]))"; };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = { type = "reduce"; refId = "B"; expression = "A"; reducer = "last"; };
                  }
                  {
                    refId = "C";
                    datasourceUid = "__expr__";
                    model = { type = "threshold"; refId = "C"; expression = "B"; conditions = [{ evaluator = { type = "gt"; params = [200]; }; }]; };
                  }
                ];
              }
              {
                uid = "se-risk-failures";
                title = "Risk Check Failures";
                condition = "C";
                for = "0s";
                noDataState = "OK";
                execErrState = "Alerting";
                labels = { severity = "critical"; };
                annotations = { summary = "Risk check failures detected"; };
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = { from = 300; to = 0; };
                    datasourceUid = "victoria-metrics";
                    model = { refId = "A"; expr = "sum(increase(risk_checks_failed_total[5m]))"; };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = { type = "reduce"; refId = "B"; expression = "A"; reducer = "last"; };
                  }
                  {
                    refId = "C";
                    datasourceUid = "__expr__";
                    model = { type = "threshold"; refId = "C"; expression = "B"; conditions = [{ evaluator = { type = "gt"; params = [0]; }; }]; };
                  }
                ];
              }
              {
                uid = "se-service-down";
                title = "SeekingEdge Service Down";
                condition = "C";
                for = "1m";
                noDataState = "Alerting";
                execErrState = "Alerting";
                labels = { severity = "critical"; };
                annotations = { summary = "SeekingEdge application metrics endpoint is unreachable"; };
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = { from = 300; to = 0; };
                    datasourceUid = "victoria-metrics";
                    model = { refId = "A"; expr = "up{job=\"seeking-edge\"}"; };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = { type = "reduce"; refId = "B"; expression = "A"; reducer = "last"; };
                  }
                  {
                    refId = "C";
                    datasourceUid = "__expr__";
                    model = { type = "threshold"; refId = "C"; expression = "B"; conditions = [{ evaluator = { type = "lt"; params = [1]; }; }]; };
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
  # };

  systemd.services.grafana.serviceConfig.RestartSec = "60"; # Retry every minute
}
