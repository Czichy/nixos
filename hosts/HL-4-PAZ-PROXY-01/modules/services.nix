{
  config.tensorfiles.services = {
    ntfy-sh.enable = true;
    monitoring = {
      # uptime-kuma.enable = true;
      healthchecks.enable = true;
      node-exporter = {
        enable = true;
        listenAddress = "127.0.0.1"; # VPS: nur lokal, kein externer Zugriff
      };
    };
    networking = {
      acme.enable = true;
      caddy.enable = true;
      networkd.enable = true;
      nftables.enable = true;
    };
  };
}
