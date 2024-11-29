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
    {system.stateVersion = _ "24.11";}
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
