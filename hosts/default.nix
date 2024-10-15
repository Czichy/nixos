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
  # config,
  withSystem,
  ...
}: {
  flake = {
    config,
    lib,
    ...
  }: let
    inherit
      (lib)
      concatMapAttrs
      filterAttrs
      flip
      genAttrs
      mapAttrs
      mapAttrs'
      nameValuePair
      ;

    # self.lib is an extended version of nixpkgs.lib
    # mkNixosIso and mkNixosSystem are my own builders for assembling a nixos system
    # provided by my local extended library
    inherit (inputs.self) lib;
    # inherit (lib) mkNixosIso mkNixosSystem mkModuleTree';
    # inherit (lib.lists) concatLists flatten singleton;

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
        inherit (inputs.self) lib;
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
              node.name = hostName;
              # node.secrets
            }
            ../modules/globals.nix
            ./${hostName}
          ]
          ++ extraModules
          # Disabled by default, therefore load every module and enable via attributes
          # instead of imports
          ++ (inputs.nixpkgs.lib.attrValues inputs.self.nixosModules)
          # ++ (inputs.nixpkgs.lib.attrValues config.flake.nixosModules)
          ++ (
            if withHomeManager
            then [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = baseSpecialArgs;
                  sharedModules = inputs.nixpkgs.lib.attrValues inputs.self.homeModules;
                  # sharedModules = inputs.nixpkgs.lib.attrValues config.flake.homeModules;
                  backupFileExtension = "backup";
                };
              }
            ]
            else []
          );
      };
  in {
    nixosConfigurations = {
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
              microvm.nixosModules.host
            ];
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
              microvm.nixosModules.host
            ];
          }
      );

      #OPNSense dummy - for Wiregard Server
      "HL-3-MRZ-FW-01" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-3-MRZ-FW-01" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (final: _prev: {nur = import nur {pkgs = final;};})
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              microvm.nixosModules.host
            ];
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
              microvm.nixosModules.host
            ];
          }
      );
    };
    # True NixOS nodes can define additional guest nodes that are built
    # together with it. We collect all defined guests from each node here
    # to allow accessing any node via the unified attribute `nodes`.
    guestConfigs = flip concatMapAttrs config.nixosConfigurations (_: node:
      flip mapAttrs' (node.config.tensorfiles.services.microvm.guests or {}) (
        guestName: guestDef:
          nameValuePair guestDef.nodeName (
            node.config.microvm.vms.${guestName}.config
          )
      ));

    # All nixosSystem instanciations are collected here, so that we can refer
    # to any system via nodes.<name>
    nodes = config.nixosConfigurations // config.guestConfigs;
    # Add a shorthand to easily target toplevel derivations
    "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
  };
}
