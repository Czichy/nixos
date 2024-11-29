{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.programs.thunderbird;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.thunderbird = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.thunderbird = {
        enable = _ true;
        # profiles.default = {
        #   isDefault = _ true;
        # };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
