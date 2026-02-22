{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    ;
  cfg = config.tensorfiles.hm.programs.games.steam;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  # TODO maybe use toINIWithGlobalSection generator? however the ini config file
  # also contains some initial keys? I should investigate this more
  options.tensorfiles.hm.programs.games.steam = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        # Steam itself is managed at system level via programs.steam.enable
        mangohud
        protontricks
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          ".local/share/Steam"
          ".local/share/Paradox Interactive"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
