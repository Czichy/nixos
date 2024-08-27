# --- parts/modules/nixos/services/networking/networkmanager.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{localFlake}: {
  config,
  lib,
  pkgs,
  pubkeys,
  inputs,
  ...
}: let
  inherit (builtins.fromTOML (builtins.readFile ./wireguard-hosts.toml)) network hosts;
  cfg = config.tensorfiles.services.networking.wireguard;
  peerable = selfHost:
    lib.filterAttrs (
      hostname: hostcfg:
        (hostname != selfHost)
        && (hostcfg ? "publicKey")
    )
    hosts;
in {
  options.tensorfiles.services.networking.wireguard = {
    enable = lib.mkEnableOption "microvm";
  };

  config = lib.mkIf (cfg.enable) (
    lib.mkMerge [
      # |----------------------------------------------------------------------| #
      (lib.mkIf (hosts."${config.networking.hostName}" ? "port") {
        networking.firewall.allowedUDPPorts = [hosts."${config.networking.hostName}".port];
      })
      # |----------------------------------------------------------------------| #
      {
        networking.wireguard.interfaces.wg0 = {
          ips = ["${hosts."${config.networking.hostName}".ip}/${toString network}"];
          privateKeyFile = "/etc/wireguard/private.key";
          generatePrivateKeyFile = true;
          listenPort = hosts."${config.networking.hostName}".port or null;

          peers = lib.mapAttrsToList (
            hostname: hostcfg:
              {
                inherit (hostcfg) publicKey;
                allowedIPs = ["${hostcfg.ip}/32"];
              }
              // (lib.optionalAttrs (hostcfg ? "endpoint") {
                endpoint = "${hostcfg.endpoint}:${toString hostcfg.port}";
                persistentKeepalive = 60;
              })
          ) (peerable config.networking.hostName);
        };

        # networkd-wait-online sometimes fails to notice that the interface is up,
        # since it's not managing it.
        systemd.network.wait-online.ignoredInterfaces = ["wg0"];
      }
      # |----------------------------------------------------------------------| #
    ]
  );
  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
