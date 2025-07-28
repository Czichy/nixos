{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.server;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.server = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;
        programs = {
          editors.helix.enable = _ true;
        };
      };

      home.sessionVariables = {
        # Default programs
        BROWSER = _ "";
        EXPLORER = _ "yazi";
        TERMINAL = _ "foot";
        EDITOR = _ "hx";
      };

      fonts.fontconfig.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
