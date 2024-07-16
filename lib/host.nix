{
  inputs,
  lib,
  ...
}: let
  defaultModules = [
    (import ../modules/default.nix)
    inputs.quadlet-nix.nixosModules.quadlet
    inputs.impermanence.nixosModules.impermanence
    inputs.sops-nix.nixosModules.sops
  ];
  unstableDefaultModules = [
    inputs.disko-unstable.nixosModules.disko
    (import ../modules-unstable/default.nix)
  ];
  stableDefaultModules = [inputs.disko-stable.nixosModules.disko];

  defaultOverlays =
    [
      inputs.nixos-extra-modules.overlays.default
      (import ../lib inputs)
      (import ../overlays/last-known-good.nix)
    ]
    ++ (import ../pkgs/default.nix inputs);

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

  mkHost = name: {
    isStable,
    system,
    path,
    hostExtraModules ? [],
    hostOverlays ? [],
  }: let
    allOverlays = hostOverlays ++ defaultOverlays;
    actual-nixpkgs =
      if isStable
      then inputs.nixpkgs-stable
      else inputs.nixpkgs-unstable;
    actual-home-manager =
      if isStable
      then inputs.home-manager-stable
      else inputs.home-manager;
    nixpkgs' = mkPkgs {
      inherit system;
      flake = actual-nixpkgs;
      overlays = allOverlays;
    };
    nixpkgs-mine = mkPkgs {
      inherit system;
      overlays = allOverlays;
      flake = inputs.nixpkgs-mine;
    };
    nixpkgs-unstable = mkPkgs {
      inherit system;
      overlays = allOverlays;
      flake = inputs.nixpkgs-unstable;
    };
  in
    actual-nixpkgs.lib.nixosSystem {
      inherit system;
      modules =
        # Everyhost gets these modules
        defaultModules
        # Some modules are only for stable or unstable hosts
        ++ (
          if isStable
          then stableDefaultModules
          else unstableDefaultModules
        )
        ++ [
          {node.secretsDir = /.${path}/secrets;}
          {
            networking.hostName = lib.mkDefault name;
            nixpkgs.overlays = allOverlays;
          }
          actual-home-manager.nixosModules.home-manager
          (import path)
        ]
        ++ hostExtraModules;

      specialArgs = {
        inherit inputs;
        mine = nixpkgs-mine;
        nixpkgs = nixpkgs';
        pkgs = nixpkgs';
        # Since we mix unstable and stable, this allows a module to get a handle on the inputs.(nixpkgs|nixpkgs-unstable) for the host
        actual-nixpkgs = actual-nixpkgs;
        unstable = nixpkgs-unstable;
        lib = nixpkgs'.lib;
      };
    };
in {
  mkHosts = hosts:
    lib.genAttrs (builtins.attrNames hosts) (
      hostName: mkHost hostName (builtins.getAttr hostName hosts)
    );
}
