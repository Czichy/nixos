# --- parts/modules/home-manager/programs/terminals/kitty.nix
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
  cfg = config.tensorfiles.hm.programs.terminals.foot;
in
#nvimScrollbackCheck =
#  cfg.nvim-scrollback.enable
#  && (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.editors.neovim");
{
  options.tensorfiles.hm.programs.terminals.foot = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles terminals.foot colorscheme generator.
    '';

    #nvim-scrollback = {
    #  enable =
    #    mkEnableOption ''
    #      TODO
    #    ''
    #    // {
    #      default = true;
    #    };
    #};

    pkg = mkOption {
      type = package;
      default = pkgs.foot;
      description = ''
        TODO
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.foot = {
        enable = true;

        settings = {
          main = {
            font = "Iosevka Nerd Font:size=12";
            # font = "${config.fontProfiles.monospace.family}:size=${toString default.terminal.size}";
            box-drawings-uses-font-glyphs = "yes";
            dpi-aware = "yes";
            pad = "0x0center";
            notify = "notify-send -a \${app-id} -i \${app-id} \${title} \${body}";
            selection-target = "primary";
          };

          scrollback = {
            lines = 100000;
            multiplier = 3;
          };

          url = {
            launch = "xdg-open \${url}";
            label-letters = "sadfjklewcmpgh";
            osc8-underline = "url-mode";
            protocols = "http, https, ftp, ftps, file";
            uri-characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.,~:;/?#@!$&%*+=\"'()[]";
          };

          cursor = {
            style = "beam";
            beam-thickness = 1;
          };
          mouse-bindings = {
            selection-override-modifiers = "Shift";
            primary-paste = "BTN_MIDDLE";
            select-begin = "BTN_LEFT";
            select-begin-block = "Control+BTN_LEFT";
            select-extend = "BTN_RIGHT";
            select-extend-character-wise = "Control+BTN_RIGHT";
            select-word = "BTN_LEFT-2";
            select-word-whitespace = "Control+BTN_LEFT-2";
          };

          colors = {
            # Dracula
            background = "282a36";
            foreground = "f8f8f2";

            ## Normal/regular colors (color palette 0-7);
            regular0 = "21222c"; # black
            regular1 = "ff5555"; # red
            regular2 = "50fa7b"; # green
            regular3 = "f1fa8c"; # yellow
            regular4 = "bd93f9"; # blue
            regular5 = "ff79c6"; # magenta
            regular6 = "8be9fd"; # cyan
            regular7 = "f8f8f2"; # white
            ## Bright colors (color palette 8-15)
            bright0 = "6272a4"; # bright black
            bright1 = "ff6e6e"; # bright red
            bright2 = "69ff94"; # bright green
            bright3 = "ffffa5"; # bright yellow
            bright4 = "d6acff"; # bright blue
            bright5 = "ff92df"; # bright magenta
            bright6 = "a4ffff"; # bright cyan
            bright7 = "ffffff"; # bright white
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
