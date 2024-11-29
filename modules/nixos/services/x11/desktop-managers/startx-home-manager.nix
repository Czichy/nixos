{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.services.x11.desktop-managers.startx-home-manager;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.services.x11.desktop-managers.startx-home-manager = with types; {
    enable = mkEnableOption ''
      Enable NixOS module that sets up the simple startx X11 displayManager with
      home-manager as the default session. This can be useful in cases where you
      want to delegate the X11 userspace completely to the user as well as its
      configuration instead of clogging your base NixOS setup.

      References
      - https://wiki.archlinux.org/title/xinit
      - https://www.x.org/releases/X11R7.6/doc/man/man1/startx.1.xhtml
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.libinput.enable = _ true;
      services.xserver = {
        enable = _ true;

        xkb.layout = "de, noted";
        xkb.variant = ",noted";
        xkb.options = "grp:sclk_toggle";
        xkb.extraLayouts = {
          noted = {
            description = "See https://github.com/dariogoetz/noted-layout";
            languages = ["de"];
            symbolsFile = ./symbols/noted;
          };
        };

        displayManager = {
          startx.enable = _ true;
          lightdm.enable = false;
          sessionCommands = ''
            # GTK2_RC_FILES must be available to the display manager.
            export GTK2_RC_FILES="$XDG_CONFIG_HOME/gtk-2.0/gtkrc"
          '';
        };

        desktopManager.session = [
          {
            name = "home-manager";
            start = ''
              ${pkgs.runtimeShell} $HOME/.xinitrc &
              waitPID=$!
            '';
          }
        ];
      };
      services.displayManager = {
        defaultSession = _ "home-manager";
        sddm.enable = false;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
