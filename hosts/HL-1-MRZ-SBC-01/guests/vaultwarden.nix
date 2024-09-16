{
  config,
  secretsPath,
  globals,
  lib,
  pkgs,
  ...
}: let
  # vaultwardenDomain = "pw.${globals.domains.personal}";
  vaultwardenDomain = "unifi.czichy.com";
in {
  microvm.mem = 1024 * 2;
  # microvm.vcpu = 20;
  # wireguard.proxy-sentinel = {
  #   client.via = "sentinel";
  #   firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.vaultwarden.config.rocketPort];
  # };

  age.secrets.vaultwarden-env = {
    file = secretsPath + "/vaultwarden-env.age";
    # rekeyFile = config.node.secretsDir + "/vaultwarden-env.age";
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

  nodes.sentinel = {
    services.nginx = {
      upstreams.vaultwarden = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.vaultwarden.config.rocketPort}" = {};
        extraConfig = ''
          zone vaultwarden 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Vaultwarden Web";
        };
      };
      virtualHosts.${vaultwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 256M;
        '';
        locations."/" = {
          proxyPass = "http://vaultwarden";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
      };
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
  systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
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

  # backups.storageBoxes.dusk = {
  #   subuser = "vaultwarden";
  #   paths = [config.services.vaultwarden.backupDir];
  # };
  systemd.network.enable = true;
  networking.hostName = "HL-1-MRZ-SBC-01-vaultwarden";
  # systemd.network.networks."99-v-lan" = {
  #   matchConfig.Type = "ether";
  #   DHCP = "yes";
  #   networkConfig = {
  #     Address = [globals.net.vlan40.hosts.HL-1-MRZ-SBC-01-adguardhome.ipv4];
  #     # Gateway = [globals.net.vlan40.cidrv4];
  #     # DNS = nameservers;
  #   };
  # };
  system.stateVersion = "24.05";
}
