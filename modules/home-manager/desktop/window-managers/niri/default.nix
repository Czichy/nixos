{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkAgenixEnableOption;

  cfg = config.tensorfiles.hm.desktop.window-managers.niri;
  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.hm.desktop.window-managers.niri = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the niriwindow manager.
    '';

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  imports = [
    inputs.niri.homeModules.niri
    ./settings.nix
    ./keybinds.nix
    ./rules.nix
    ./autostart.nix
    ./xwayland-satellite.nix
    ./qalculate.nix
  ];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home = {
        packages = with pkgs; [
          labwc
          jaq
          xprop
          xdg-desktop-portal-gnome
          # xdg-desktop-portal-hyprland
        ];
      };

      programs.niri = {
        enable = true;
        package = pkgs.niri;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
