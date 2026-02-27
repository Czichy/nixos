{
  lib,
  inputs,
  withSystem,
  config,
  ...
}: let
  mkHome = args: home: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    ...
  }:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit (args) pkgs;
      extraSpecialArgs =
        {
          inherit (args) system;
          inherit inputs home;
          inherit (inputs.self) globals;
        }
        // extraSpecialArgs;
      modules =
        [
          {
            nixpkgs.overlays = extraOverlays;
            nixpkgs.config.allowUnfree = true;
          }
          ./${home}
        ]
        ++ extraModules
        # Disabled by default, therefore load every module and enable via attributes
        # instead of imports
        ++ (lib.attrValues config.flake.homeModules);
    };
in {
  options.flake.homeConfigurations = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = {};
  };

  config = {
    flake.homeConfigurations = {
      "czichy@desktop" = withSystem "x86_64-linux" (
        args:
          mkHome args "czichy@desktop" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );

      "czichy@server" = withSystem "x86_64-linux" (
        args:
          mkHome args "czichy@server" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );

      "root" = withSystem "x86_64-linux" (
        args:
          mkHome args "root" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );
    };

    flake.checks."x86_64-linux" = {
      "home-czichy@desktop" = config.flake.homeConfigurations."czichy@desktop".config.home.path;
      "home-czichy@server" = config.flake.homeConfigurations."czichy@server".config.home.path;
      "root" = config.flake.homeConfigurations."root".config.home.path;
    };
  };
}
