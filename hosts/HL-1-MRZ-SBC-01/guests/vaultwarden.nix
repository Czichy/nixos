{
  config,
  secretsPath,
  globals,
  lib,
  # pkgs,
  ...
}: let
  # vaultwardenDomain = "pw.${globals.domains.personal}";
  vaultwardenDomain = "vaultwarden.czichy.com";
in {
  # microvm.mem = 1024 * 2;
  # microvm.vcpu = 20;
  # tensorfiles.services.networking.wireguard.proxy-sentinel = {
  #   client.via = "sentinel";
  #   firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.vaultwarden.config.rocketPort];
  # };

  # age.secrets.vaultwarden-env = {
  #   file = secretsPath + "/vaultwarden-env.age";
  #   # rekeyFile = config.node.secretsDir + "/vaultwarden-env.age";
  #   mode = "440";
  #   group = "vaultwarden";
  # };

  # environment.persistence."/persist".directories = [
  #   {
  #     directory = "/var/lib/vaultwarden";
  #     user = "vaultwarden";
  #     group = "vaultwarden";
  #     mode = "0700";
  #   }
  # ];

  # globals.services.vaultwarden.domain = vaultwardenDomain;
  # globals.monitoring.http.vaultwarden = {
  #   url = "https://${vaultwardenDomain}";
  #   expectedBodyRegex = "Vaultwarden Web";
  #   network = "internet";
  # };

  # nodes.sentinel = {
  #   services.nginx = {
  #     upstreams.vaultwarden = {
  #       # servers."${config.tensorfiles.services.networking.wireguard.proxy-sentinel.ipv4}:${toString config.services.vaultwarden.config.rocketPort}" = {};
  #       extraConfig = ''
  #         zone vaultwarden 64k;
  #         keepalive 2;
  #       '';
  #       monitoring = {
  #         enable = true;
  #         expectedBodyRegex = "Vaultwarden Web";
  #       };
  #     };
  #     virtualHosts.${vaultwardenDomain} = {
  #       forceSSL = true;
  #       useACMEWildcardHost = true;
  #       extraConfig = ''
  #         client_max_body_size 256M;
  #       '';
  #       locations."/" = {
  #         proxyPass = "http://vaultwarden";
  #         proxyWebsockets = true;
  #         X-Frame-Options = "SAMEORIGIN";
  #       };
  #     };
  #   };
  # };
  # networking.firewall = {
  #   allowedTCPPorts = [22 8012];
  #   allowedUDPPorts = [22 8012];
  # };

  # services.vaultwarden = {
  #   enable = true;
  #   dbBackend = "sqlite";
  #   # WARN: Careful! The backup script does not remove files in the backup location
  #   # if they were removed in the original location! Therefore, we use a directory
  #   # that is not persisted and thus clean on every reboot.
  #   backupDir = "/var/cache/vaultwarden-backup";
  #   config = {
  #     dataFolder = lib.mkForce "/var/lib/vaultwarden";
  #     extendedLogging = true;
  #     useSyslog = true;
  #     webVaultEnabled = true;

  #     rocketAddress = "0.0.0.0";
  #     rocketPort = 8012;

  #     signupsAllowed = false;
  #     passwordIterations = 1000000;
  #     invitationsAllowed = true;
  #     invitationOrgName = "Vaultwarden";
  #     domain = "https://${vaultwardenDomain}";

  #     smtpEmbedImages = true;
  #     smtpSecurity = "force_tls";
  #     smtpPort = 465;
  #   };
  #   # Admin secret token, see
  #   # https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page
  #   #ADMIN_TOKEN=...copy-paste a unique generated secret token here...
  #   environmentFile = config.age.secrets.vaultwarden-env.path;
  # };

  # Replace uses of old name
  # systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce "/var/lib/vaultwarden";
  # systemd.services.vaultwarden.serviceConfig = {
  #   StateDirectory = lib.mkForce "vaultwarden";
  #   RestartSec = "60"; # Retry every minute
  # };

  # Needed so we don't run out of tmpfs space for large backups.
  # Technically this could be cleared each boot but whatever.
  # environment.persistence."/state".directories = [
  #   {
  #     directory = config.services.vaultwarden.backupDir;
  #     user = "vaultwarden";
  #     group = "vaultwarden";
  #     mode = "0700";
  #   }
  # ];

  # backups.storageBoxes.dusk = {
  #   subuser = "vaultwarden";
  #   paths = [config.services.vaultwarden.backupDir];
  # };

  networking.firewall = {
    allowedTCPPorts = [53 80 443 3000];
    allowedUDPPorts = [53];
  };

  # topology.self.services.adguardhome.info = "https://" + adguardhomeDomain;
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;
    settings = {
      dns = {
        # port = 53;
        # allowed_clients = [
        # ];
        #trusted_proxies = [];
        ratelimit = 300;
        bind_hosts = ["::"];
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "https://doh.mullvad.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          # FIXME: enable ipv6 "2606:4700:4700::1111"
          "8.8.8.8"
          # FIXME: enable ipv6 "2001:4860:4860::8844"
        ];
        dhcp.enabled = false;
      };
      filtering.rewrites =
        [
          # Undo the /etc/hosts entry so we don't answer with the internal
          # wireguard address for influxdb
          {
            # inherit (globals.services.influxdb) domain;
            # answer = config.repo.secrets.global.domains.me;
          }
        ]
        # Use the local mirror-proxy for some services (not necessary, just for speed)
        ++ map (domain: {
          inherit domain;
          answer = globals.net.home-lan.hosts.ward-web-proxy.ipv4;
        }) [
          # FIXME: dont hardcode, filter global service domains by internal state
          # globals.services.grafana.domain
          # globals.services.immich.domain
          # globals.services.influxdb.domain
          # "home.${config.repo.secrets.global.domains.me}"
          # "fritzbox.${config.repo.secrets.global.domains.me}"
        ];
      filters = [
        {
          name = "AdGuard DNS filter";
          url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
          enabled = true;
        }
        {
          name = "AdAway Default Blocklist";
          url = "https://adaway.org/hosts.txt";
          enabled = true;
        }
        {
          name = "OISD (Big)";
          url = "https://big.oisd.nl";
          enabled = true;
        }
      ];
    };
  };

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
