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
      flip
      mapAttrs
      mapAttrs'
      nameValuePair
      ;

    # self.lib is an extended version of nixpkgs.lib
    # mkNixosIso and mkNixosSystem are my own builders for assembling a nixos system
    # provided by my local extended library
    inherit (inputs.self) lib;

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
              # (final: _prev: {ceph-client = import ../flake-parts/overlays/ceph-client.nix;})
              nix-topology.overlays.default
              nixos-extra-modules.overlays.default
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              microvm.nixosModules.host
              # nur.modules.nixos.default
            ];
          }
      );
      "HL-1-MRZ-HOST-01" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-1-MRZ-HOST-01" {
            withHomeManager = true;
            extraOverlays = with inputs; [
              (
                final: _prev: {
                  nur = import nur {pkgs = final;};
                  affine-server = prev.callPackage ../pkgs/affine-server.nix {};
                }
              )
            ];
            extraModules = with inputs; [
              nix-topology.nixosModules.default
              nixos-nftables-firewall.nixosModules.default
              microvm.nixosModules.host
            ];
          }
      );
      "HL-1-MRZ-HOST-02" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-1-MRZ-HOST-02" {
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

      "HL-1-MRZ-HOST-03" = withSystem "x86_64-linux" (
        args:
          mkHost args "HL-1-MRZ-HOST-03" {
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
      #   #OPNSense dummy - for Wiregard Server
      #   "HL-3-MRZ-FW-01" = withSystem "x86_64-linux" (
      #     args:
      #       mkHost args "HL-3-MRZ-FW-01" {
      #         withHomeManager = true;
      #         extraOverlays = with inputs; [
      #           (final: _prev: {nur = import nur {pkgs = final;};})
      #         ];
      #         extraModules = with inputs; [
      #           nix-topology.nixosModules.default
      #           nixos-nftables-firewall.nixosModules.default
      #           microvm.nixosModules.host
      #         ];
      #       }
      #   );
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
