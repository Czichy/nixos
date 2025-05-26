{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.services.printing;
in {
  options.tensorfiles.services.printing = with types; {
    enable = mkEnableOption ''

      Enables NixOS module that sets up the basis for the userspace, that is
      declarative management, basis for the home directories and also
      configures home-manager, persistence, agenix if they are enabled.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.printing.enable = true;
      services.printing.drivers = [pkgs.gutenprint];

      services.printing.browsing = true;
      services.printing.browsedConf = ''

        BrowseDNSSDSubTypes _cups,_print
        BrowseLocalProtocols all
        BrowseRemoteProtocols all
        CreateIPPPrinterQueues All

        BrowseProtocols all
      '';
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        # for a WiFi printer
        openFirewall = true;
      };

      hardware.printers = {
        ensureDefaultPrinter = "BrotherMFC";
        ensurePrinters = [
          {
            name = "BrotherMFC";
            location = "Buero";
            description = "Brother MFC-L3750CDW";
            deviceUri = "ipp://10.15.10.253/ipp";
            model = "everywhere";
          }
        ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
