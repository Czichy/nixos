{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtModuleLevel
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.services.networking.networkmanager;
  _ = mkOverrideAtModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.networking.networkmanager = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the networkmanager service.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {networking.networkmanager.enable = _ true;}
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      systemd.tmpfiles.rules = [
        "L /var/lib/NetworkManager/secret_key - - - - /persist/var/lib/NetworkManager/secret_key"
        "L /var/lib/NetworkManager/seen-bssids - - - - /persist/var/lib/NetworkManager/seen-bssids"
        "L /var/lib/NetworkManager/timestamps - - - - /persist/var/lib/NetworkManager/timestamps"
      ];
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = ["/etc/NetworkManager/system-connections"];
        files = [
          "/var/lib/NetworkManager/secret_key" # TODO probably move elsewhere?
          # "/var/lib/NetworkManager/seen-bssids"
          # "/var/lib/NetworkManager/timestamps"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
