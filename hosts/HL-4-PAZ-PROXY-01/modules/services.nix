{
  config.tensorfiles.services = {
    networking = {
      networkd.enable = true;
      nftables.enable = true;
      acme.enable = true;
      caddy.enable = true;
    };
  };
}
