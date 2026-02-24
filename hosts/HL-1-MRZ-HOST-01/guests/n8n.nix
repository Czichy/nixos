{
  config,
  globals,
  lib,
  secretsPath,
  pkgs,
  ...
}: let
  n8nDomain = "n8n.${globals.domains.me}";
  n8nPort = 5678;

  certloc = "/var/lib/acme-sync/czichy.com";

  # ---------------------------------------------------------------------------
  # Ollama-Anbindung (nativ auf HOST-01, GPU-beschleunigt)
  # ---------------------------------------------------------------------------
  # n8n hat native Ollama-Nodes (Chat, Embeddings, AI Agent).
  # Credential in n8n-UI anlegen: Type "Ollama", URL = ollamaUrl
  ollamaUrl = "http://${globals.net.vlan40.hosts.HL-1-MRZ-HOST-01.ipv4}:11434";

  # ---------------------------------------------------------------------------
  # Edu-Search PostgreSQL (Read-Only-Zugriff für Workflows)
  # ---------------------------------------------------------------------------
  # n8n greift lesend auf die edu-search DB zu für:
  # - Benachrichtigungen über neu indexierte Materialien
  # - Wöchentliche Status-Reports
  # - Fehler-Eskalation bei Pipeline-Problemen
  # - KI-generierte Quizfragen aus indexiertem Material
  # Credential in n8n-UI anlegen: Type "Postgres",
  #   Host = eduSearchDbHost, Port = 5432, DB = edu_search,
  #   User = n8n_reader, Password = edu_n8n_readonly
  eduSearchDbHost = globals.net.vlan40.hosts."HL-3-RZ-EDU-01".ipv4;
in {
  # |----------------------------------------------------------------------| #
  globals.services.n8n = {
    domain = n8nDomain;
    homepage = {
      enable = true;
      name = "n8n";
      icon = "sh-n8n";
      description = "Workflow Automation Platform";
      category = "Automation";
      priority = 30;
      abbr = "N8N";
    };
  };
  networking.hostName = "HL-3-RZ-N8N-01";

  networking.firewall = {
    allowedTCPPorts = [n8nPort];
  };
  # |----------------------------------------------------------------------| #
  nodes.HL-4-PAZ-PROXY-01 = {
    services.caddy = {
      virtualHosts."${n8nDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
                tls_insecure_skip_verify
                tls_server_name ${n8nDomain}
            }
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${n8nDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-N8N-01".ipv4}:${toString n8nPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  # |----------------------------------------------------------------------| #
  age.secrets.n8n-encryption-key = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/n8n/encryption-key.age";
    mode = "440";
    owner = "n8n";
    group = "n8n";
  };
  age.secrets.n8n-anthropic-api-key = {
    file = secretsPath + "/claude/anthropic-api-key.age";
    mode = "440";
    owner = "n8n";
    group = "n8n";
  };
  # -- Backup secrets --
  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };
  age.secrets.restic-n8n = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/n8n/restic-n8n.age";
    mode = "440";
  };
  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };
  age.secrets.n8n-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # |----------------------------------------------------------------------| #
  users.users.n8n = {
    isSystemUser = true;
    group = "n8n";
  };
  users.groups.n8n = {};
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/n8n";
      user = "n8n";
      group = "n8n";
      mode = "0700";
    }
  ];
  # |----------------------------------------------------------------------| #
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment = {
      # Workaround: nixpkgs n8n module partitions env vars with _FILE suffix
      # into LoadCredential entries, but N8N_RUNNERS_AUTH_TOKEN_FILE defaults
      # to null → "cannot coerce null to a string". Set to /dev/null since
      # task runners are not enabled.
      N8N_RUNNERS_AUTH_TOKEN_FILE = lib.mkForce "/dev/null";
      N8N_PORT = toString n8nPort;
      N8N_LISTEN_ADDRESS = "0.0.0.0";
      GENERIC_TIMEZONE = "Europe/Berlin";
      N8N_PROTOCOL = "http";
      N8N_HOST = n8nDomain;
      WEBHOOK_URL = "https://${n8nDomain}/";
      N8N_EDITOR_BASE_URL = "https://${n8nDomain}/";
      N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n-encryption-key.path;

      # ----- KI-Backends (für n8n Ollama/Claude Nodes) -----
      # Ollama-URL wird via CREDENTIALS_OVERWRITE_DATA injiziert (siehe n8n-setup-env).
      # Anthropic API-Key wird ebenfalls automatisch injiziert.
      # In der n8n-UI müssen Credentials vom Typ "Ollama" und "Anthropic"
      # angelegt werden – die Werte werden automatisch überschrieben.
      OLLAMA_BASE_URL = ollamaUrl;

      # ----- Edu-Search DB-Verbindung (Read-Only) -----
      EDU_SEARCH_DB_HOST = eduSearchDbHost;
      EDU_SEARCH_DB_PORT = "5432";
      EDU_SEARCH_DB_NAME = "edu_search";
      EDU_SEARCH_DB_USER = "n8n_reader";
    };
  };

  systemd.services.n8n-setup-env = {
    description = "Prepare n8n environment secrets";
    wantedBy = ["n8n.service"];
    before = ["n8n.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "n8n";
      RuntimeDirectoryPreserve = "yes";
      ExecStart = pkgs.writeShellScript "n8n-setup-env" ''
        ANTHROPIC_KEY="$(cat ${config.age.secrets.n8n-anthropic-api-key.path} | tr -d '\n')"
        {
          echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY"
          echo 'CREDENTIALS_OVERWRITE_DATA={"anthropicApi":{"apiKey":"'"$ANTHROPIC_KEY"'"},"ollamaApi":{"baseUrl":"${ollamaUrl}"}}'
        } > /run/n8n/env
        chown n8n:n8n /run/n8n/env
        chmod 400 /run/n8n/env
      '';
    };
  };

  systemd.services.n8n = {
    after = ["n8n-setup-env.service"];
    requires = ["n8n-setup-env.service"];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "n8n";
      Group = "n8n";
      StateDirectory = "n8n";
      EnvironmentFile = "/run/n8n/env";
    };
    environment = {
      HOME = "/var/lib/n8n";
    };
  };
  # |----------------------------------------------------------------------| #
  # -- Restic Backup --
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/backup/restic.nix
  services.restic.backups = let
    ntfy_pass = "$(cat ${config.age.secrets.ntfy-alert-pass.path})";
    ntfy_url = "https://${globals.services.ntfy-sh.domain}/backups";
    slug = "https://health.czichy.com/ping/";

    script-post = host: site: ''
      pingKey="$(cat ${config.age.secrets.n8n-hc-ping.path})"
      if [ $EXIT_STATUS -ne 0 ]; then
        ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
        -H 'Title: Backup (${site}) on ${host} failed!' \
        -H 'Tags: backup,restic,${host},${site}' \
        -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}/fail"
      else
        ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/backup-${site}"
      fi
    '';
  in {
    n8n-backup = {
      # Initialize the repository if it doesn't exist.
      initialize = true;

      # backup to a rclone remote
      repository = "rclone:onedrive_nas:/backup/${config.networking.hostName}-n8n";

      # Which local paths to backup.
      paths = ["/var/lib/n8n"];

      # Patterns to exclude when backing up.
      exclude = [
        "/var/lib/n8n/.cache"
        "/var/lib/n8n/.npm"
      ];

      passwordFile = config.age.secrets.restic-n8n.path;
      rcloneConfigFile = config.age.secrets."rclone.conf".path;

      # A script that must run after finishing the backup process.
      backupCleanupCommand = script-post config.networking.hostName "n8n";

      # Prune old snapshots.
      pruneOpts = [
        "--keep-daily 3"
        "--keep-weekly 3"
        "--keep-monthly 3"
        "--keep-yearly 3"
      ];

      # When to run the backup. See systemd.timer(5) for details.
      timerConfig = {
        OnCalendar = "*-*-* 03:00:00";
      };
    };
  };
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
