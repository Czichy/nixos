{
  config.tensorfiles.services = {
    networking.networkd.enable = true;
    virtualisation.enable = true;
    monitoring.node-exporter.enable = true;
  };
}
