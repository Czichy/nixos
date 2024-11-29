{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.graphical-startx-home-manager;
  _ = mkOverrideAtProfileLevel;
in {
  options.tensorfiles.profiles.graphical-startx-home-manager = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles = {
        profiles.headless.enable = _ true;

        services.x11.desktop-managers.startx-home-manager.enable = _ true;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
