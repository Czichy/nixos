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
{ localFlake, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib.tensorfiles) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.graphical-hyprland;
  _ = mkOverrideAtProfileLevel;
in
{
  options.tensorfiles.profiles.graphical-hyprland = with types; {
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

      environment.systemPackages = with pkgs; [
        # -- GENERAL PACKAGES --
        #libnotify # A library that sends desktop notifications to a notification daemon
        #notify-desktop # Little application that lets you send desktop notifications with one command
        wl-clipboard # Command-line copy/paste utilities for Wayland
        #maim # A command-line screenshot utility

        wireshark # Powerful network protocol analyzer
        #pgadmin4-desktopmode # Administration and development platform for PostgreSQL. Desktop Mode
        #mqttui # Terminal client for MQTT
        #mqttx # Powerful cross-platform MQTT 5.0 Desktop, CLI, and WebSocket client tools

        # -- UTILS NEEDED FOR INFO-CENTER --
        clinfo # Print all known information about all available OpenCL platforms and devices in the system
        glxinfo # Test utilities for OpenGL
        vulkan-tools # Khronos official Vulkan Tools and Utilities
        wayland-utils # Wayland utilities (wayland-info)
        #aha # ANSI HTML Adapter

        # -- KDE PACKAGES --
        kdePackages.kate # Advanced text editor
        kdePackages.kcalc # Scientific calculator
        kdePackages.kalarm # Personal alarm scheduler
      ];

      services.xserver.enable = _ true;
      programs.partition-manager.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
