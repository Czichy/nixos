{
  config.tensorfiles.services = {
    networking = {
      networkd.enable = true;
      acme.enable = true;
      caddy.enable = true;
    };
  };
}
