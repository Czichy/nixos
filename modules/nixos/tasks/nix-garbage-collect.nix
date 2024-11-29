{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.tasks.nix-garbage-collect;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.tasks.nix-garbage-collect = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures the task handling periodic nix store
      garbage collection.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      nix.gc = {
        automatic = _ true;
        dates = _ "weekly";
        options = _ "--delete-older-than 7d";
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
