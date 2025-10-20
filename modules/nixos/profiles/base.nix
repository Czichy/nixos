{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.base;
  _ = mkOverrideAtProfileLevel;

  # Pfad zur kopierten Root-CA-Datei im Flake-Repository
  internalCARoot = ../../../assets/certs/caddy_internal_root.crt;
in {
  options.tensorfiles.profiles.base = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the base system profile.

      **Base layer** sets up necessary structures to be able to simply
      just evaluate the configuration, ie. not build it, meaning that this layer
      enables fundamental functionality that other higher level modules rely
      on.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      # Aktiviert die PKI-Dienste (falls nicht bereits geschehen)
      # security.pki.enable = true;

      # Importiert die Root-CA-Datei in den globalen System-Trust-Store
      security.pki.certificateFiles = [internalCARoot];
      #   {
      #     # Laden der Datei aus dem Flake
      #     cert = builtins.readFile internalCARoot;

      #     # Name, wie es im Zertifikatsmanager erscheinen soll
      #     name = "Caddy Internal CA for czichy.com";
      #   }
      # ];
    }
    {system.stateVersion = _ "24.11";}
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
