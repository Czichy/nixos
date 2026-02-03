{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.services.networking.networkd;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.services.networking.networkd = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles defaults regarding nix
      language & nix package manager.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      networking = {
        useNetworkd = true;
        dhcpcd.enable = false;
        useDHCP = false;
        # allow mdns port
        firewall.allowedUDPPorts = [5353];
        # firewall.allowedTCPPorts = [3000 80 53 443];
        # renameInterfacesByMac = lib.mkIf (!config.boot.isContainer) (
        #   lib.mapAttrs (_: v: v.mac) (config.secrets.secrets.local.networking.interfaces or {})
        # );
      };
      systemd.network = {
        enable = true;
        wait-online.anyInterface = true;
      };
      services.resolved = {
        enable = true;
        settings = {
          Resolve = {
            # man I whish dnssec would be viable to use
            DNSSEC = false;
            LLMNR = false;
            FallbackDNS = [
              "1.1.1.1"
              "2606:4700:4700::1111"
              "8.8.8.8"
              "2001:4860:4860::8844"
            ];
            Domains = "~.";
            MulticastDNS = true;
            # Disable local DNS stub listener on 127.0.0.53
            DNSStubListener = false;
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
