# --- parts/hosts/default.nix
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
  mkHost = args: hostName: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    withHomeManager ? false,
    ...
  }: let
    baseSpecialArgs =
      {
        inherit (args) system;
        inherit inputs hostName;
        inherit (config) globals;
      }
      // extraSpecialArgs;
  in
    lib.nixosSystem {
      inherit (args) system;
      specialArgs =
        baseSpecialArgs
        // {
          inherit lib hostName;
          host.hostName = hostName;
        };
      modules =
        [
          {
            nixpkgs.overlays = extraOverlays;
            nixpkgs.config.allowUnfree = true;
            networking.hostName = hostName;
            # node.name = hostName;
          }
          ./${hostName}
        ]
        ++ extraModules
        # Disabled by default, therefore load every module and enable via attributes
        # instead of imports
        ++ (lib.attrValues config.flake.nixosModules)
        ++ (
          if withHomeManager
          then [
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = baseSpecialArgs;
                sharedModules = lib.attrValues config.flake.homeModules;
                backupFileExtension = "backup";
              };
            }
          ]
          else []
        );
    };
in {
  flake.nixosConfigurations = {
    installer = withSystem "x86_64-linux" (
      args:
        mkHost args "installer" {
          withHomeManager = false;
          extraOverlays = with inputs; [(final: _prev: {nur = import nur {pkgs = final;};})];
        }
    );

    desktop = withSystem "x86_64-linux" (
      args:
        mkHost args "desktop" {
          withHomeManager = true;
          extraOverlays = with inputs; [
            (final: _prev: {nur = import nur {pkgs = final;};})
            nix-topology.overlays.default
            # (final: _prev: {nixos_extra = import nixos-extra-modules.overlays.default {pkgs = final;};})
          ];
          extraModules = with inputs; [nix-topology.nixosModules.default];
        }
    );
    vm_test = withSystem "x86_64-linux" (
      args:
        mkHost args "vm_test" {
          withHomeManager = true;
          extraOverlays = with inputs; [(final: _prev: {nur = import nur {pkgs = final;};})];
        }
    );
    home_server_test = withSystem "x86_64-linux" (
      args:
        mkHost args "home_server_test" {
          withHomeManager = true;
          extraOverlays = with inputs; [
            (final: _prev: {nur = import nur {pkgs = final;};})
            nix-topology.overlays.default
            # (final: _prev: {nixos_extra = import nixos-extra-modules.overlays.default {pkgs = final;};})
          ];
          extraModules = with inputs; [
            nix-topology.nixosModules.default
          ];
        }
    );
    spinorbundle = withSystem "x86_64-linux" (
      args:
        mkHost args "spinorbundle" {
          withHomeManager = true;
          extraOverlays = with inputs; [(final: _prev: {nur = import nur {pkgs = final;};})];
        }
    );
    jetbundle = withSystem "x86_64-linux" (
      args:
        mkHost args "jetbundle" {
          withHomeManager = true;
          extraOverlays = with inputs; [(final: _prev: {nur = import nur {pkgs = final;};})];
        }
    );
  };
}
