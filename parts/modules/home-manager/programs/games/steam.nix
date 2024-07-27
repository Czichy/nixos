# --- parts/modules/home-manager/programs/games/steam.nix
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
{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib.tensorfiles)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    ;
  steam-with-pkgs = pkgs.steam.override {
    extraPkgs = pkgs:
      with pkgs; [
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXScrnSaver
        libpng
        libpulseaudio
        libvorbis
        stdenv.cc.cc.lib
        libkrb5
        keyutils
        gamescope
        mangohud
      ];
  };

  # steam-session = pkgs.writeTextDir "share/wayland-sessions/steam-sesson.desktop" ''
  #   [Desktop Entry]
  #   Name=Steam Session
  #   Exec=${pkgs.gamescope}/bin/gamescope -W ${toString monitor.width} -H ${toString monitor.height} -O ${monitor.name} -e -- steam -gamepadui
  #   Type=Application
  # '';

  cfg = config.tensorfiles.hm.programs.games.steam;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  # TODO maybe use toINIWithGlobalSection generator? however the ini config file
  # also contains some initial keys? I should investigate this more
  options.tensorfiles.hm.programs.games.steam = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        steam-with-pkgs
        # steam-session
        # gamescope
        mangohud
        protontricks
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        allowOther = true;
        directories = [
          ".local/share/Steam"
          # Minecraft Bedrock Launcher
          # https://mcpelauncher.readthedocs.io/en/latest/index.html
          ".config/Minecraft Linux Launcher"
          ".local/share/mcpelauncher"
          ".local/share/mcpelauncher-webview"
          ".local/share/Minecraft Linux Launcher"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
