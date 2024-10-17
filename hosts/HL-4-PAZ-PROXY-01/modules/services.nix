{
  config.tensorfiles.services = {
    ntfy-sh.enable = true;
    uptime-kuma.enable = true;
    networking = {
      acme.enable = true;
      caddy.enable = true;
      networkd.enable = true;
      nftables.enable = true;
    };
  };
}
