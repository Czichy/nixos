{
  config,
  globals,
  secretsPath,
  lib,
  ...
}: let
  vaultwardenDomain = "vault.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
in {
  # microvm.mem = 1024 * 2;
  # microvm.vcpu = 20;
  networking.hostName = "HL-3-RZ-VAULT-01";

  age.secrets.vaultwarden-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-SBC-01/guests/vaultwarden/vaultwarden-env.age";
    mode = "440";
    group = "vaultwarden";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  globals.services.vaultwarden.domain = vaultwardenDomain;
  globals.monitoring.http.vaultwarden = {
    url = "https://${vaultwardenDomain}";
    expectedBodyRegex = "Vaultwarden Web";
    network = "internet";
  };

  networking.firewall = {
    allowedTCPPorts = [22 8012];
    allowedUDPPorts = [22 8012];
  };

  nodes.HL-4-PAZ-PROXY-01 = {
    # SSL config and forwarding to local reverse proxy
    services.caddy = {
      virtualHosts."${vaultwardenDomain}".extraConfig = ''
        reverse_proxy https://10.15.70.1:443 {
            transport http {
            	tls_server_name ${vaultwardenDomain}
            }
        }

        tls ${certloc}/cert.pem ${certloc}/key.pem {
          protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  nodes.HL-1-MRZ-SBC-01-caddy = {
    services.caddy = {
      virtualHosts."${vaultwardenDomain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-VAULT-01".ipv4}:${toString config.services.vaultwarden.config.rocketPort}
        tls ${certloc}/cert.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    # WARN: Careful! The backup script does not remove files in the backup location
    # if they were removed in the original location! Therefore, we use a directory
    # that is not persisted and thus clean on every reboot.
    backupDir = "/var/cache/vaultwarden-backup";
    config = {
      dataFolder = lib.mkForce "/var/lib/vaultwarden";
      extendedLogging = true;
      useSyslog = true;
      webVaultEnabled = true;

      rocketAddress = "0.0.0.0";
      rocketPort = 8012;

      signupsAllowed = false;
      passwordIterations = 1000000;
      invitationsAllowed = true;
      invitationOrgName = "Vaultwarden";
      domain = "https://${vaultwardenDomain}";

      smtpEmbedImages = true;
      smtpSecurity = "force_tls";
      smtpPort = 465;
    };
    # Admin secret token, see
    # https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page
    #ADMIN_TOKEN=...copy-paste a unique generated secret token here...
    environmentFile = config.age.secrets.vaultwarden-env.path;
  };

  # Replace uses of old name
  # systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
  systemd.services.vaultwarden.serviceConfig = {
    StateDirectory = lib.mkForce "vaultwarden";
    RestartSec = "60"; # Retry every minute
  };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  environment.persistence."/state".directories = [
    {
      directory = config.services.vaultwarden.backupDir;
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
  ];

  system.stateVersion = "24.05";
}
