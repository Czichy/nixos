{
  config.tensorfiles.services = {
    networking.networkd.enable = true;
    virtualisation.enable = true;
    telegraf = {
      enable = true;
      scrapeSensors = false; # Hypervisor - keine direkten Sensoren
      availableMonitoringNetworks = [ "internet" "local-HL-1-MRZ-HOST-01" ];
      influxdb2 = {
        domain = "influxdb.czichy.com";
        organization = "machines";
        bucket = "telegraf";
        node = "HL-3-RZ-INFLUX-01";
      };
    };
  };
}
