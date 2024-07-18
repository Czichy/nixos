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
  inputs,
  withSystem,
  config,
  ...
}: {
  flake = {
    lib,
    pkgs,
    ...
  }: let
    inherit config;
    mkPkgs = {
      system,
      flake,
      overlays ? [],
    }:
      import flake {
        inherit system overlays;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
          "electron-24.8.6"
          "electron-27.3.11"
        ];
      };
    mkHost = args: hostName: {
      system,
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
      inputs.nixpkgs.lib.nixosSystem {
        inherit (args) system;
        specialArgs =
          baseSpecialArgs
          // {
            inherit inputs;
            inherit system;
            inherit hostName;
            host.hostName = hostName;
            inherit (pkgs) lib;
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
          ++ (inputs.nixpkgs.lib.attrValues config.flake.nixosModules)
          ++ (
            if withHomeManager
            then [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = baseSpecialArgs;
                  sharedModules = inputs.nixpkgs.lib.attrValues config.flake.homeModules;
                  backupFileExtension = "backup";
                };
              }
            ]
            else []
          );
      };
  in {
    nixosConfigurations = {
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
              nixos-extra-modules.overlays.default
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              # nixos-extra-modules.nixosModules.default
              # {
              #   # We cannot force the package set via nixpkgs.pkgs and
              #   # inputs.nixpkgs.nixosModules.readOnlyPkgs, since nixosModules
              #   # should be able to dynamicall add overlays via nixpkgs.overlays.
              #   # So we just mimic the options and overlays defined by the passed pkgs set
              #   # to not lose what we already have defined below.
              #   nixpkgs.hostPlatform = system;
              #   nixpkgs.overlays = pkgs.overlays;
              #   nixpkgs.config = pkgs.config;
              # }
            ];
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
            system = "x86_64-linux";
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
              nix-topology.overlays.default
              nixos-extra-modules.overlays.default
              {inherit system;}
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              nixos-extra-modules.nixosModules.default
              {
                #   # We cannot force the package set via nixpkgs.pkgs and
                #   # inputs.nixpkgs.nixosModules.readOnlyPkgs, since nixosModules
                #   # should be able to dynamicall add overlays via nixpkgs.overlays.
                #   # So we just mimic the options and overlays defined by the passed pkgs set
                #   # to not lose what we already have defined below.
                nixpkgs.hostPlatform = system;
                nixpkgs.overlays = pkgs.overlays;
                nixpkgs.config = pkgs.config;
              }
            ];

            # baseSpecialArgs = {
            #   inherit (pkgs) lib;
            # };
          }
      );
    };
  };
}
