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
      security.pki.certificateFiles = [
        internalCARoot
      ];

      security.pki.certificates = [
        ''          -----BEGIN CERTIFICATE-----
                    MIIBnjCCAUOgAwIBAgIQW3kPv59+Jd2dJi7M0Cg7IDAKBggqhkjOPQQDAjAtMSsw
                    KQYDVQQDDCJjemljaHlfaW50ZXJuYWxfY2EgLSAyMDI1IEVDQyBSb290MB4XDTI1
                    MTAyMDA4MjMxMVoXDTM1MDgyOTA4MjMxMVowLTErMCkGA1UEAwwiY3ppY2h5X2lu
                    dGVybmFsX2NhIC0gMjAyNSBFQ0MgUm9vdDBZMBMGByqGSM49AgEGCCqGSM49AwEH
                    A0IABH3OdKvArYcniu0qwyILcU0wzmgOSJO4AaNVfgOh/Cszv5wrNOgkBBzVvp8z
                    R/GO3tebAGLZnXvOF3E8SxSK5pijRTBDMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMB
                    Af8ECDAGAQH/AgEBMB0GA1UdDgQWBBT/W8WeeqzPAfDxWziPgEgNGWPLADAKBggq
                    hkjOPQQDAgNJADBGAiEAv7Z/g5JSRiEIlBNwUp/e96DOM/45J1SFLI3U8w8leIAC
                    IQDEKzph44+pidsaa/Q4Wra47krfjkngOH0/JOOv7vG1Ig==
                    -----END CERTIFICATE-----''
      ];
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
