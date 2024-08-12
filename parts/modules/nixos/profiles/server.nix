# --- parts/modules/nixos/profiles/graphical-hyprland.nix
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
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib.tensorfiles) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.server;
  _ = mkOverrideAtProfileLevel;
in {
  options.tensorfiles.profiles.server = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles = {
        profiles.headless.enable = _ true;

        services.x11.desktop-managers.startx-home-manager.enable = _ true;
      };

      # environment.systemPackages = with pkgs; [
      # -- GENERAL PACKAGES --
      #libnotify # A library that sends desktop notifications to a notification daemon
      #notify-desktop # Little application that lets you send desktop notifications with one command
      # wl-clipboard # Command-line copy/paste utilities for Wayland
      #pgadmin4-desktopmode # Administration and development platform for PostgreSQL. Desktop Mode
      #mqttui # Terminal client for MQTT
      #mqttx # Powerful cross-platform MQTT 5.0 Desktop, CLI, and WebSocket client tools
      # ];

      services.xserver.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
