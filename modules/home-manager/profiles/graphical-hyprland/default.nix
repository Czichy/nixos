{localFlake}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical-hyprland;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical-hyprland = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        desktop.window-managers.hyprland.enable = _ true;
        profiles.graphical.enable = _ true;
        services.swaync.enable = _ true;
        programs = {
          wlogout.enable = _ true;
          walker.enable = _ true;
        };
      };

      services.rsibreak.enable = _ false;

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;

      programs = {
        # fish.loginShellInit = ''
        #   if test (tty) = "/dev/tty1"
        #     set _JAVA_AWT_WM_NONEREPARENTING 1
        #     exec Hyprland &> /dev/null
        #   end
        # '';
        #  zsh.loginExtra = ''
        #    if [ "$(tty)" = "/dev/tty1" ]; then
        #      exec Hyprland &> /dev/null
        #    fi
        #  '';
        #  zsh.profileExtra = ''
        #    if [ "$(tty)" = "/dev/tty1" ]; then
        #      exec Hyprland &> /dev/null
        #    fi
        #  '';
      };
      # ## WARN: Check if this breaks when the hyprland module is not in imports.
      # ## Enter Hyprland when logging into tty1 if Hyprland is enabled.
      # xdg.configFile."nushell/login.nu".text = ''
      #   if (tty) == "/dev/tty1" {
      #     exec Hyprland | ignore
      #   }
      # '';
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
