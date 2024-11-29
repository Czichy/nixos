{
  localFlake,
  inputs,
}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical-plasma;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical-plasma = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  imports = with inputs; [plasma-manager.homeManagerModules.plasma-manager];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    (import ./rc2nix.nix)
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;

        # hardware.nixGL.enable = _ true;

        programs = {
          newsboat.enable = _ true;
          pywal.enable = _ true;
          terminals.kitty.enable = _ true;
          browsers.firefox.enable = _ true;
          editors.helix.enable = _ true;
          #thunderbird.enable = _ true;
        };

        services = {
          pywalfox-native.enable = _ true;
        };
      };

      home.packages = with pkgs; [
        vscode-fhs # Wrapped variant of vscode which launches in a FHS compatible environment. Should allow for easy usage of extensions without nix-specific modifications.
      ];

      services.flameshot = {
        enable = _ true;
        settings = {
          General.showStartupLaunchMessage = _ false;
        };
      };

      services.rsibreak.enable = _ false;

      home.sessionVariables = {
        # Default programs
        BROWSER = _ "firefox";
        TERMINAL = _ "kitty";
        IDE = _ "code";
      };

      fonts.fontconfig.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
