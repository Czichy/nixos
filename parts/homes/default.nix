# --- parts/homes/default.nix
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
      "czichy@jetbundle" = withSystem "x86_64-linux" (
        args:
          mkHome args "czichy@jetbundle" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );

      "czichy@vm_test " = withSystem "x86_64-linux" (
        args:
          mkHome args "czichy@vm_test" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );

      "czichy@desktop" = withSystem "x86_64-linux" (
        args:
          mkHome args "czichy@desktop" {
            extraOverlays = with inputs; [(final: _prev: {nur = import inputs.nur {pkgs = final;};})];
          }
      );
    };

    flake.checks."x86_64-linux" = {
      "home-czichy@jetbundle" = config.flake.homeConfigurations."czichy@jetbundle".config.home.path;
      "home-czichy@desktop" = config.flake.homeConfigurations."czichy@desktop".config.home.path;
    };
  };
}
