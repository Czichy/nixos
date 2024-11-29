{
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.services.x11.desktop-managers.plasma;
in {
  options.tensorfiles.services.x11.desktop-managers.plasma = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      # services.xserver.desktopManager.plasma.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);
}
