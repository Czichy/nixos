{localFlake}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical-niri;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical-niri = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        desktop.window-managers.niri.enable = _ true;
        profiles.graphical.enable = _ true;
        services.swaync.enable = _ true;
        programs = {
          wlogout.enable = _ true;
          walker.enable = _ true;
        };
      };

      services.rsibreak.enable = _ false;

      home.packages = with pkgs; [
      ];

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;

      # using greetd!?
      #   programs = {
      #     fish.loginShellInit = ''
      #       # if test (tty) = "/dev/tty1"
      #         # set _JAVA_AWT_WM_NONEREPARENTING 1
      #         # niri-session
      #         # exit
      #       # end
      #       # if test (tty) = "/dev/tty1"
      #       #   set _JAVA_AWT_WM_NONEREPARENTING 1
      #       #   pgrep niri >/dev/null || exec niri-session
      #       # end
      #     '';
      #     #  zsh.loginExtra = ''
      #     #    if [ "$(tty)" = "/dev/tty1" ]; then
      #     #      exec Hyprland &> /dev/null
      #     #    fi
      #     #  '';
      #     #  zsh.profileExtra = ''
      #     #    if [ "$(tty)" = "/dev/tty1" ]; then
      #     #      exec Hyprland &> /dev/null
      #     #    fi
      #     #  '';
      #   };
      #   ## WARN: Check if this breaks when the hyprland module is not in imports.
      #   ## Enter Hyprland when logging into tty1 if Hyprland is enabled.
      #   xdg.configFile."nushell/login.nu".text = ''
      #     if (tty) == "/dev/tty1" {
      #       exec niri-session | ignore
      #     }
      #   '';
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
