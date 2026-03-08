{localFlake}: {
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.tensorfiles.services.monitoring.node-exporter;
in {
  options.tensorfiles.services.monitoring.node-exporter = with types; {
    enable = mkEnableOption "prometheus node-exporter for system metrics";

    port = mkOption {
      type = port;
      default = 9100;
      description = "Port for node-exporter to listen on.";
    };

    listenAddress = mkOption {
      type = str;
      default = "0.0.0.0";
      description = "Address node-exporter listens on.";
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = cfg.listenAddress;
      port = cfg.port;
      enabledCollectors = [
        "cpu"
        "meminfo"
        "diskstats"
        "filesystem"
        "netdev"
        "loadavg"
        "systemd"
        "processes"
      ];
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
