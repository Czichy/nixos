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
  self,
  inputs,
  lib,
  withSystem,
  config,
  ...
}: rec {
  # let
  mkArgs = system:
    withSystem system (systemArgs: {
      inherit self inputs;

      inherit
        (systemArgs)
        self'
        inputs'
        selfPkgs
        stablePkgs
        unstablePkgs
        ;
    });

  mkPkgs = {
    system,
    flake,
    overlays ? [],
  }:
    import flake {
      inherit system overlays;
      config.allowUnfree = true;
      # config.permittedInsecurePackages = [
      #   "electron-25.9.0"
      #   "electron-24.8.6"
      #   "electron-27.3.11"
      # ];
    };

  mkHost = args: hostName: {
    extraSpecialArgs ? {},
    extraModules ? [],
    extraOverlays ? [],
    withHomeManager ? false,
    ...
  }: let
    nixpkgs' = mkPkgs {
      inherit (args) system;
      flake = inputs.nixpkgs;
      overlays = defaultOverlays ++ extraOverlays;
    };
    baseSpecialArgs =
      {
        inherit (args) system;
        inherit inputs hostName;
        inherit (config) globals;
        pkgs = nixpkgs';
        lib = nixpkgs';
      }
      // extraSpecialArgs;
    defaultOverlays = with inputs; [
      (final: _prev: {nur = import nur {pkgs = final;};})
      nix-topology.overlays.default
      nixos-extra-modules.overlays.default
    ];
  in
    lib.nixosSystem {
      inherit (args) system;
      specialArgs =
        baseSpecialArgs
        // {
          inherit self inputs;
          inherit hostName;
          host.hostName = hostName;
        };
      modules =
        [
          {
            nixpkgs.overlays = defaultOverlays ++ extraOverlays;
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
  # in {
  #   mkHosts = hosts:
  #     lib.genAttrs (builtins.attrNames hosts) (
  #       hostName: mkHost hostName (builtins.getAttr hostName hosts)
  #     );
}
