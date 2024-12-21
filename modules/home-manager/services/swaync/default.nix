# --- parts/modules/home-manager/services/dunst.nix
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
{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel mkPywalEnableOption;

  cfg = config.tensorfiles.hm.services.swaync;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.services.swaync = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        iosevka
        swaynotificationcenter
        libnotify
        nerd-fonts.iosevka
      ];

      services.swaync = {
        enable = _ true;
        settings = {
          positionX = "right";
          positionY = "top";

          layer = "overlay";
          layer-shell = true;
          cssPriority = "application";

          control-center-layer = "top";
          control-center-width = 800;
          control-center-height = 1600;
          control-center-margin-top = 0;
          control-center-margin-bottom = 0;
          control-center-margin-right = 0;
          control-center-margin-left = 0;

          notification-window-width = 800;
          notification-2fa-action = true;
          notification-inline-replies = false;
          notification-icon-size = 64;
          notification-body-image-height = 100;
          notification-body-image-width = 200;

          keyboard-shortcuts = true;
          image-visibility = "when-available";
          transition-time = 100;

          widgets = [
            "inhibitors"
            "dnd"
            "mpris"
            "notifications"
          ];

          widget-config = {
            inhibitors = {
              text = "Inhibitors";
              button-text = "Clear All";
              clear-all-button = true;
            };
            title = {
              text = "Notifications";
              clear-all-button = true;
              button-text = "Clear All";
            };
            dnd = {
              text = "Do Not Disturb";
            };
            label = {
              max-lines = 5;
              text = "Label Text";
            };
            mpris = {
              image-size = 96;
              blur = true;
            };
          };
        };
        style =
          #lib.concatLines (
          #  map (c: "@define-color ${c} ${config.lib.stylix.colors.withHashtag.${c}};") [
          #    "base00"
          #    "base01"
          #    "base02"
          #    "base03"
          #    "base04"
          #    "base05"
          #    "base06"
          #    "base07"
          #    "base08"
          #    "base09"
          #    "base0A"
          #    "base0B"
          #    "base0C"
          #    "base0D"
          #    "base0E"
          #    "base0F"
          #  ]
          #)
          #+
          builtins.readFile ./swaync-style.css;
      };

      # Started via hyprland to ensure it restarts properly with hyprland
      systemd.user.services.swaync.Install.WantedBy = lib.mkForce [];
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
