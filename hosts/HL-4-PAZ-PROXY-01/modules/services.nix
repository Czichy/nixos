{
  config.tensorfiles.services = {
    ntfy-sh.enable = true;
    monitoring = {
      # uptime-kuma.enable = true;
      healthchecks.enable = true;
    };
    networking = {
      acme.enable = true;
      caddy.enable = true;
      networkd.enable = true;
      nftables.enable = true;
    };
  };
}
