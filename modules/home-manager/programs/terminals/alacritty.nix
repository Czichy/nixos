{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.programs.terminals.alacritty;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.terminals.alacritty = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [meslo-lgs-nf];

      programs.alacritty = {
        enable = _ true;
        settings = {
          window = {
            opacity = _ 0.8;
            decorations = _ "full";
          };
          dynamic_title = _ true;
          font = {
            size = _ 7.0;
            normal.family = _ "MesloLGS NF";
          };
          bell.duration = _ 0;
          cursor.style.shape = _ "Block";
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
