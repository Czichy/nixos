# --- parts/modules/home-manager/programs/tmux.nix
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
  # inherit (localFlake.lib.tensorfiles) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.programs.zellij;
in
{
  options.tensorfiles.hm.programs.zellij = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.zellij = {
        enable = true;
        settings = {
          theme = if pkgs.system == "aarch64-darwin" then "dracula" else "default";
          # https://github.com/nix-community/home-manager/issues/3854
          themes.dracula = {
            fg = [
              248
              248
              242
            ];
            bg = [
              40
              42
              54
            ];
            black = [
              0
              0
              0
            ];
            red = [
              255
              85
              85
            ];
            green = [
              80
              250
              123
            ];
            yellow = [
              241
              250
              140
            ];
            blue = [
              98
              114
              164
            ];
            magenta = [
              255
              121
              198
            ];
            cyan = [
              139
              233
              253
            ];
            white = [
              255
              255
              255
            ];
            orange = [
              255
              184
              108
            ];
          };
          scroll-buffer-size = 50000;
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
