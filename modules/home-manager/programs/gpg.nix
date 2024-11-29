{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel isModuleLoadedAndEnabled;

  cfg = config.tensorfiles.hm.programs.gpg;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.gpg = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.gpg = {
        enable = _ true;
      };

      services.gpg-agent = {
        enable = _ true;
        pinentryPackage = _ pkgs.pinentry-qt;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
        enableZshIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh");
      };

      programs.git.signing = {
        signByDefault = _ true;
        key = _ null;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
