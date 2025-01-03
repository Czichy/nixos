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
  cfg = config.tensorfiles.hm.programs.terminals.ghostty;
  ghostty = inputs.ghostty.packages.${pkgs.system}.default;
in {
  options.tensorfiles.hm.programs.terminals.ghostty = with types; {
    enable = mkEnableOption "Enables Ghostty configuration management through home-manager";

    makeDefault = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to make this terminal default by setting TERMINAL env var";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home = {
        # packages = lib.optional (cfg.package != null) cfg.package;
        sessionVariables.TERMINAL = mkIf cfg.makeDefault "ghostty";
      };
      programs.ghostty = {
        enable = true;
        package = ghostty;
        settings = {
          auto-update = "off";
          background-opacity = 0.8;
          confirm-close-surface = false;
          font-family = "FiraCode Nerd Font Mono";
          font-size = 12;
          theme = "Teerb";
          keybind = [
            "clear"
            "ctrl+h=goto_split:left"
            "ctrl+l=goto_split:right"
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
