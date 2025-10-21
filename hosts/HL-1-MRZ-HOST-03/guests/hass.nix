{
  config,
  globals,
  lib,
  nodes,
  pkgs,
  secretsPath,
  ...
}: let
  homeassistantDomain = "home.${globals.domains.me}";
  certloc = "/var/lib/acme-sync/czichy.com";
in {
  microvm.mem = 4196;
  microvm.vcpu = 4;

  networking.hostName = "HL-3-RZ-HASS-01";
  globals.services.home-assistant.domain = homeassistantDomain;
  # globals.monitoring.http.homeassistant = {
  #   url = "https://${homeasisstantDomain}";
  #   expectedBodyRegex = "homeassistant";
  #   network = "internet";
  # };
  #
  imports = [
    ./hass/mqtt-sensors.nix
    # ./hass-modbus/mennekes-amtron-xtra.nix
  ];

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [
      config.services.home-assistant.config.http.server_port
    ];
  };
  # Der äußere Caddy (HL-4-PAZ-PROXY-01) muss die Verbindung zum inneren Caddy
  # über HTTPS aufbauen. Da es sich um eine interne Verbindung handelt und der
  # innere Caddy möglicherweise ein selbst-signiertes Zertifikat verwendet,
  # müssen Sie die Zertifikatsprüfung deaktivieren.
  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${homeassistantDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
          transport http{
            # Da der innere Caddy ein eigenes Zertifikat ausstellt,
            # muss die Überprüfung auf dem äußeren Caddy übersprungen werden.
            tls_insecure_skip_verify
            tls_server_name ${homeassistantDomain}
          }
        }
        tls ${certloc}/cert.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
      # ''
      #   reverse_proxy https://10.15.70.1:443{
      #       transport http {
      #       	tls_server_name ${vaultwardenDomain}
      #       }
      #   }

      #   tls ${certloc}/cert.pem ${certloc}/key.pem {
      #     protocols tls1.3
      #   }
      #   import czichy_headers
      # '';
    };
  };
  # Der innere Caddy (HL-1-MRZ-HOST-02-caddy) muss nun ein eigenes TLS-Zertifikat bereitstellen,
  # damit der äußere Caddy eine sichere Verbindung aufbauen kann.
  # Der innere Caddy muss auch seine eigene reverse_proxy-Verbindung zum
  # Vaultwarden-Server über HTTPS herstellen.
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${homeassistantDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-VAULT-01".ipv4}:8123
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  # |----------------------------------------------------------------------| #
  # services.matter-server = {
  #   enable = true;
  #   logLevel = "debug";
  # };

  topology.self.services.home-assistant.info = "https://${homeassistantDomain}";
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "esphome"
      "fritzbox"
      "matter"
      "met"
      "mqtt"
      "ntfy"
      "ollama"
      "radio_browser"
      "solax"
      "unifi"
      "vicare"
      "wake_word"
      "whisper"
      "wyoming"
      "zha"
    ];

    customComponents = with pkgs.home-assistant-custom-components; [
      # (pkgs.home-assistant.python.pkgs.callPackage ./hass-components/ha-bambulab.nix {})
      dwd
      solax_modbus
      waste_collection_schedule
    ];

    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      (pkgs.callPackage ./hass/lovelace/config-template-card/package.nix {})
      (pkgs.callPackage ./hass/lovelace/hui-element/package.nix {})
      apexcharts-card
      bubble-card
      button-card
      card-mod
      clock-weather-card
      hourly-weather
      lg-webos-remote-control
      mini-graph-card
      multiple-entity-row
      mushroom
      weather-card
      weather-chart-card
    ];

    config = {
      default_config = {};
      http = {
        server_host = ["0.0.0.0"];
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = ["10.15.70.1"];
        # trusted_proxies = [nodes.ward-web-proxy.config.wireguard.proxy-home.ipv4];
      };

      zha.zigpy_config.source_routing = true;

      homeassistant = {
        name = "!secret ha_name";
        latitude = "!secret ha_latitude";
        longitude = "!secret ha_longitude";
        elevation = "!secret ha_elevation";
        currency = "EUR";
        time_zone = "Europe/Berlin";
        unit_system = "metric";
        external_url = "https://${homeassistantDomain}";
        internal_url = "https://${homeassistantDomain}";
        packages.manual = "!include manual.yaml";
      };

      lovelace.mode = "yaml";

      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      "automation ui" = "!include automations.yaml";
      "scene" = "!include scenes.yaml";

      influxdb = {
        api_version = 2;
        host = globals.net.vlan40.hosts."HL-3-RZ-INFLUX-01".ipv4;
        port = "8086";
        max_retries = 10;
        ssl = false;
        verify_ssl = false;
        token = "!secret influxdb_token";
        organization = "home";
        bucket = "home_assistant";
      };

      waste_collection_schedule = {
        sources = [
          {
            name = "ics";
            args.url = "!secret muell_ics_url";
            calendar_title = "Abfalltermine";
            customize = [
              {
                type = "Restmüll 2-wöchentlich";
                alias = "Restmüll";
              }
              {
                type = "Papiertonne 4-wöchentlich";
                alias = "Papiermüll";
              }
            ];
          }
        ];
      };

      sensor = [
        {
          platform = "waste_collection_schedule";
          name = "restmuell_upcoming";
          value_template = "{{value.types|join(\", \")}}|{{value.daysTo}}|{{value.date.strftime(\"%d.%m.%Y\")}}|{{value.date.strftime(\"%a\")}}";
          types = ["Restmüll"];
        }
        {
          platform = "waste_collection_schedule";
          name = "papiermuell_upcoming";
          value_template = "{{value.types|join(\", \")}}|{{value.daysTo}}|{{value.date.strftime(\"%d.%m.%Y\")}}|{{value.date.strftime(\"%a\")}}";
          types = ["Papiermüll"];
        }
      ];
    };

    extraPackages = python3Packages:
      with python3Packages; [
        # adguardhome
        aioelectricitymaps
        dwdwfsapi
        # fritzconnection
        getmac
        gtts
        psycopg2
        pyatv
        pyipp
        pymodbus
        zlib-ng
      ];
  };

  age.secrets."home-assistant-secrets.yaml" = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/hass/home-assistant-secrets.yaml.age";
    mode = "440";
    group = "hass";
  };
  age.secrets.influxdb-user-home_assistant-token = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/influxdb/home_assistant-token.age";
    mode = "440";
    group = "hass";
  };

  systemd.services.home-assistant = {
    serviceConfig.LoadCredential = [
      "hass-influxdb-token:${config.age.secrets.influxdb-user-home_assistant-token.path}"
    ];
    preStart = lib.mkBefore ''
      if [[ -e ${config.services.home-assistant.configDir}/secrets.yaml ]]; then
        rm ${config.services.home-assistant.configDir}/secrets.yaml
      fi

      # Update influxdb token
      # We don't use -i because it would require chown with is a @privileged syscall
      INFLUXDB_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/hass-influxdb-token")" \
        ${lib.getExe pkgs.yq-go} '.influxdb_token = strenv(INFLUXDB_TOKEN)' \
        ${
        config.age.secrets."home-assistant-secrets.yaml".path
      } > ${config.services.home-assistant.configDir}/secrets.yaml

      touch -a ${config.services.home-assistant.configDir}/{automations,scenes,scripts,manual}.yaml
    '';
  };
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".directories = [
    {
      directory = config.services.home-assistant.configDir;
      user = "hass";
      group = "hass";
      mode = "0700";
    }
  ];

  # Connect to fritzbox via https proxy (to ensure valid cert)
  # networking.hosts.${globals.net.home-lan.vlans.services.hosts.ward-web-proxy.ipv4} = [
  #   fritzboxDomain
  # ];

  # networking.hosts.${nodes.ward-adguardhome.config.wireguard.proxy-home.ipv4} = [
  #   "adguardhome.internal"
  # ];

  # nodes.ward-web-proxy = {
  #   services.nginx = {
  #     upstreams."home-assistant" = {
  #       servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.home-assistant.config.http.server_port}" = {};
  #       extraConfig = ''
  #         zone home-assistant 64k;
  #         keepalive 2;
  #       '';
  #     };
  #     virtualHosts.${homeassistantDomain} = {
  #       forceSSL = true;
  #       useACMEWildcardHost = true;
  #       locations."/" = {
  #         proxyPass = "http://home-assistant";
  #         proxyWebsockets = true;
  #       };
  #       extraConfig = ''
  #         allow ${globals.net.home-lan.vlans.home.cidrv4};
  #         allow ${globals.net.home-lan.vlans.home.cidrv6};
  #         allow ${globals.net.home-lan.vlans.devices.cidrv4};
  #         allow ${globals.net.home-lan.vlans.devices.cidrv6};
  #         # Self-traffic (needed for media in Voice PE)
  #         allow ${globals.net.home-lan.vlans.services.hosts.sausebiene.ipv4};
  #         allow ${globals.net.home-lan.vlans.services.hosts.sausebiene.ipv6};
  #         # Firezone traffic
  #         allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
  #         allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
  #         deny all;
  #       '';
  #     };
  #   };
  # };
}
