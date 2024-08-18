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
  self,
  withSystem,
  config,
  ...
}: {
  flake = let
    inherit config;
    mkHost = args: hostName: {
      extraSpecialArgs ? {},
      extraModules ? [],
      extraOverlays ? [],
      withHomeManager ? false,
      ...
    }: let
      defaultOverlays = with inputs; [
        nix-topology.overlays.default
      ];
      baseSpecialArgs =
        {
          inherit (args) system;
          inherit inputs hostName;
          inherit (self) nodes globals;
        }
        // extraSpecialArgs;
    in
      inputs.nixpkgs.lib.nixosSystem {
        inherit (args) system;
        specialArgs =
          baseSpecialArgs
          // {
            inherit inputs;
            inherit hostName;
            host.hostName = hostName;
          };
        modules =
          [
            {
              nixpkgs.overlays = defaultOverlays; # ++ extraOverlays;
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
              nix-flatpak.nixosModules.nix-flatpak
            ];
          }
      );
      "HL-1-OZ-PC-01" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-1-OZ-PC-01" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
              nix-topology.overlays.default
              nixos-extra-modules.overlays.default
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              nix-flatpak.nixosModules.nix-flatpak
              microvm.nixosModules.host
            ];
          }
      );
      home_server_test = withSystem "x86_64-linux" (
        args:
          mkHost args "home_server_test" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              # nix-flatpak.nixosModules.nix-flatpak
            ];
            extraSpecialArgs = {
              inherit (self) globals;
            };
          }
      );
      #ward
      "HL-1-MRZ-SBC-01" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-1-MRZ-SBC-01" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              # nix-flatpak.nixosModules.nix-flatpak
              microvm.nixosModules.host
            ];
            extraSpecialArgs = {
              inherit (self) globals;
            };
          }
      );

      #sentinel
      "HL-4-PAZ-PROXY-01" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-4-PAZ-PROXY-01" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              # nix-flatpak.nixosModules.nix-flatpak
            ];
            extraSpecialArgs = {
              inherit (self) globals;
            };
          }
      );
      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = config.nixosConfigurations // config.guestConfigs;
      # Add a shorthand to easily target toplevel derivations
      # "@" = self.lib.mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
    };
  };
}
