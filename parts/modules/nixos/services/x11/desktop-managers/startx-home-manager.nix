# --- parts/modules/nixos/services/x11/desktop-managers/startx-home-manager.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{ localFlake }:
{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.services.x11.desktop-managers.startx-home-manager;
  _ = mkOverrideAtModuleLevel;
in
{
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
            languages = [ "de" ];
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

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
