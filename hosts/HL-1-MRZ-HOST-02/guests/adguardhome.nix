{
  config,
  globals,
  ...
}: let
  adguardhomeDomain = "adguardhome.czichy.com";
  certloc = "/var/lib/acme-sync/czichy.com";
  # adguardhomeDomain = "adguardhome.${config.repo.secrets.global.domains.me}";
  filter-dir = "https://adguardteam.github.io/HostlistsRegistry/assets";
in {
  networking.hostName = "HL-3-RZ-DNS-01";

  # AdGuard Home deactivated. DNS rewrites migrated to OPNsense Unbound.
  # See hosts/HL-1-MRZ-HOST-02/guests.nix for migration notes.
  #
  # globals.services.adguardhome = { ... };
  # globals.monitoring.dns.adguardhome = { ... };

  # Caddy vHost removed — no longer needed without AdGuard service.
  # nodes.HL-1-MRZ-HOST-02-caddy = { ... };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/AdGuardHome";
      mode = "0700";
    }
  ];

  networking.firewall = {
    allowedTCPPorts = [53 80 443 3000];
    allowedUDPPorts = [53];
  };

  services.adguardhome = {
    enable = false;
    mutableSettings = false;
    host = "0.0.0.0";
    port = 3000;
    settings = {
      dns = {
        ratelimit = 300;
        bind_hosts = ["::"];
        upstream_dns = [
          "https://dns.cloudflare.com/dns-query"
          "https://dns.google/dns-query"
          "https://doh.mullvad.net/dns-query"
        ];
        bootstrap_dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        dhcp.enabled = false;
        rewrites = [
          # Migrated to OPNsense: Services → Unbound DNS → Overrides → Host Overrides
          # vault.czichy.com    → 10.15.40.22
          # home.czichy.com     → 10.15.70.1
          # red.czichy.com      → 10.15.70.1
          # influxdb.czichy.com → 10.15.70.1
          # metrics.czichy.com  → 10.15.70.1
        ];
      };
      filtering.rewrites = [];
      filters = [
        # Migrated to OPNsense: Services → Unbound DNS → Blocklist
        # - AdGuard DNS filter:  https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
        # - AdAway:              https://adaway.org/hosts.txt
        # - OISD Big:            https://big.oisd.nl
      ];
    };
  };

  systemd.network.enable = true;
  systemd.network.wait-online.enable = true;
  system.stateVersion = "24.05";
}
