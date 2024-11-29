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
  # inherit
  #   (localFlake.lib)
  #   ;
  cfg = config.tensorfiles.hm.programs.ragenix;

  ragenix = inputs.agenix.packages.x86_64-linux.default;
in {
  # TODO modularize config, cant be bothered to do it now
  options.tensorfiles.hm.programs.ragenix = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the neovim program.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        ragenix
        rage
      ];
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
