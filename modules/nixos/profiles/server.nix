{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

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

      xdg.icons.enable = _ false;
      xdg.mime.enable = _ false;
      xdg.sounds.enable = _ false;

      documentation.man.enable = _ false;
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

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
