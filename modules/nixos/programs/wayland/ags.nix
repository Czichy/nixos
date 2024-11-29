{
  localFlake,
  inputs,
}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.programs.wayland.ags;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.programs.wayland.ags = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the ags.nix app launcher


       https://github.com/Aylur/ags
    '';

    # home = {
    #   enable = mkHomeEnableOption;

    #   settings = mkHomeSettingsOption (_user: {});
    # };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    (mkIf cfg.home.enable {
      services.upower.enable = _ true;
      home-manager.users = genAttrs (attrNames cfg.home.settings) (_user: {
        # Since this module is completely isolated and single purpose
        # (meaning that the only possible place to import it from tensorfiles
        # is here) we can leave the import call here
        imports = [inputs.ags.homeManagerModules.default];

        programs.ags = {
          enable = _ true;
          # extraPackages = with pkgs; [
          #   sassc
          #   swww
          #   brightnessctl
          #   slurp
          # ];
        };
      });
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
