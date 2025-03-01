{
  description = "czichy's fully covariant tensorfiles";

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    ...
  }: let
    inherit (inputs) nixpkgs;

    # properties = import (self + /assets/properties);
    # You should ideally use relative paths in each individual part from ./parts,
    # however, if needed you can use the `projectPath` variable that is passed
    # to every flakeModule to properly anchor your absolute paths.
    projectPath = ./.;

    # We extend the base <nixpkgs> library with our own custom helpers as well
    # as override any of the nixpkgs default functions that we'd like
    # to override. This instance is then passed to every part in ./parts so that
    # you can use it in your custom modules
    lib = import ./parts/lib {inherit inputs;} // nixpkgs.lib;
    specialArgs = {
      inherit lib projectPath;
    };
  in
    flake-parts.lib.mkFlake {inherit inputs specialArgs;} {
      # Systems for which attributes of perSystem will be built. As
      # a rule of thumb, only systems provided by available hosts
      # should go in this list. More systems will increase evaluation
      # duration.
      systems = import inputs.systems;

      imports = [
        ./parts # Parts of the flake that are used to construct the final flake.
        ./modules
        ./hosts # Entrypoint for host configurations of my systems.
        ./homes
        ./topology/flake-module.nix
      ];
      debug = true;
    };
  inputs = {
    # --- BASE DEPENDENCIES -----------------------------------------
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    systems.url = "github:nix-systems/default";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # --- DEV DEPENDENCIES ------------------------------------------
    devenv.url = "github:cachix/devenv";
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # --- SECRET DEPENDENCIES ---------------------------------------
    agenix = {
      url = "github:ryantm/agenix";
      #   url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # my private secrets, it's a private repository, you need to replace it with your own.
    # use ssh protocol to authenticate via ssh-agent/ssh-key, and shallow clone to save time
    private = {
      # url = "git+ssh://git@github.com/czichy/nix-secrets.git?ref=restructure&shallow=1";
      url = "git+ssh://git@github.com/czichy/nix-secrets.git?shallow=1";
      flake = false;
    };

    # --- UTILITIES -------------------------------------------------
    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hardware.url = "github:NixOS/nixos-hardware/master";

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-inspect.url = "github:bluskript/nix-inspect";

    nixos-nftables-firewall = {
      url = "github:thelegy/nixos-nftables-firewall";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-extra-modules = {
      url = "github:czichy/nixos-extra-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    arkenfox-user-js = {
      url = "github:arkenfox/user.js";
      flake = false;
    };
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      # nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs";
    };

    lib-net = {
      url = "https://gist.github.com/duairc/5c9bb3c922e5d501a1edb9e7b3b845ba/archive/3885f7cd9ed0a746a9d675da6f265d41e9fd6704.tar.gz";
      flake = false;
    };

    # Sandbox wrappers for programs
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
      };
    };
    # This exists, I guess
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nix-alien.url = "github:thiagokokada/nix-alien";

    # --- PACKAGES --------------------------------------------------
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
    };

    helix = {
      url = "github:helix-editor/helix/master";
      inputs.nixpkgs.follows = "nixpkgs"; # ok?
    };
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.4.1";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    nix-minecraft = {
      url = "github:Misterio77/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ibkr-rust = {
      url = "github:czichy/ibkr-rust";
    };

    power-meter = {
      url = "github:czichy/power-meter";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # NOTE Here you can add additional binary cache substituers that you trust.
  # There are also some sensible default caches commented out that you
  # might consider using.
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org/"
      "https://devenv.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];
  };
}
