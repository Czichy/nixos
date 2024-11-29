{localFlake}: {
  config,
  lib,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.tasks.system-autoupgrade;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.tasks.system-autoupgrade = with types; {
    enable = mkEnableOption ''
      Module enabling system wide nixpkgs & host autoupgrade
      Enables NixOS module that configures the task handling periodix nixpkgs
      and host autoupgrades.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      system.autoUpgrade = {
        enable = _ false;
        flake = _ "github:czichy/tensorfiles#${config.networking.hostName}";
        # channel = _ "https://nixos.org/channels/nixos-unstable";
        allowReboot = _ true;
        randomizedDelaySec = _ "5m";
        rebootWindow = {
          lower = _ "02:00";
          upper = _ "05:00";
        };
        flags = [
          "--impure"
          "--accept-flake-config"
        ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
