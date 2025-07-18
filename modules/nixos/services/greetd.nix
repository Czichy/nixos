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
  inherit (localFlake.lib) mkOverrideAtModuleLevel;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;
  cfg = config.tensorfiles.services.greetd;
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;

  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.services.greetd = with types; {
    enable =
      mkEnableOption ''
      '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --remember  --asterisks  --container-padding 2 --no-xsession-wrapper --cmd Hyprland --kb-command 5";
            user = "greeter";
          };
        };
      };

      # this is a life saver.
      # literally no documentation about this anywhere.
      # might be good to write about this...
      # https://www.reddit.com/r/NixOS/comments/u0cdpi/tuigreet_with_xmonad_how/

      systemd = {
        # To prevent getting stuck at shutdown
        extraConfig = "DefaultTimeoutStopSec=10s";
        services.greetd.serviceConfig = {
          Type = "idle";
          StandardInput = "tty";
          StandardOutput = "tty";
          StandardError = "journal";
          TTYReset = true;
          TTYVHangup = true;
          TTYVTDisallocate = true;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    # (lib.mkIf impermanenceCheck {
    #   environment.persistence."${impermanence.persistentRoot}" = {
    #     directories = ["/var/lib/flatpak"];
    #   };
    # })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
