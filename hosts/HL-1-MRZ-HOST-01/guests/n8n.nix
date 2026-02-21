{
  config,
  globals,
  secretsPath,
  pkgs,
  ...
}: let
  n8nDomain = "n8n.${globals.domains.me}";
  n8nPort = 5678;

  certloc = "/var/lib/acme-sync/czichy.com";
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
    settings = {
      port = n8nPort;
      listen_address = "0.0.0.0";
      generic = {
        timezone = "Europe/Berlin";
      };
      protocol = "http";
      host = n8nDomain;
      webhook_url = "https://${n8nDomain}/";
      editor_base_url = "https://${n8nDomain}/";
    };
  };

  systemd.services.n8n = {
    serviceConfig = {
      User = "n8n";
      Group = "n8n";
      StateDirectory = "n8n";
      EnvironmentFile = [];
    };
    environment = {
      N8N_ENCRYPTION_KEY_FILE = config.age.secrets.n8n-encryption-key.path;
      HOME = "/var/lib/n8n";
    };
  };
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
