# --- parts/modules/home-manager/programs/dmenu.nix
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
  inherit (localFlake.lib) mkPywalEnableOption;

  cfg = config.tensorfiles.hm.programs.wofi;

in
{
  options.tensorfiles.hm.programs.wofi = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };

    pkg = mkOption {
      type = package;
      default = pkgs.dmenu;
      description = ''
        Which package to use for the dmenu binaries. You can provide any
        custom derivation of your choice as long as the main binaries
        reside at

        - `$pkg/bin/dmenu`
        - `$pkg/bin/dmenu_run`
        - etc...
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.wofi = {
        enable = true;
        settings = {
          width = 600;
          height = 500;
          location = "center";
          show = "drun";
          prompt = "Search...";
          filter_rate = 100;
          allow_markup = true;
          no_actions = true;
          halign = "fill";
          orientation = "vertical";
          content_haligh = "fill";
          insensitive = true;
          allow_images = true;
          image_size = 40;
          gtk_dark = true;
          dynamic_lines = true;
        };
        style = ''
          * {
            font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
            font-size: 16px;
          }

          window {
          margin: 0px;
          border: none;
          border-radius: 10px;
          background-color: #00060A;
          }

          #input {
          margin: 5px;
          border: none;
          color: #f2f4f8;
          background-color: #00060A;
          }

          #inner-box {
          margin: 5px;
          border: none;
          background-color: #00060A;
          }

          #outer-box {
          margin: 5px;
          border: none;
          background-color: #00060A;
          }

          #scroll {
          margin: 0px;
          border: none;
          }

          #text {
          margin: 5px;
          border: none;
          color: #f2f4f8;
          }

          #entry:selected {
          background-color: #33b1ff;
          }
        '';
      };

      #xdg.configFile."wofi/config-bmenu".text = toConfig {
      #  width = 375;
      #  height = 450;
      #  location = "top_left";
      #  show = "drun";
      #  prompt = "Search...";
      #  filter_rate = 100;
      #  allow_markup = true;
      #  no_actions = false;
      #  halign = "fill";
      #  orientation = "vertical";
      #  content_halign = "fill";
      #  insensitive = true;
      #  allow_images = true;
      #  image_size = 32;
      #  gtk_dark = true;
      #  layer = "top";
      #};
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
