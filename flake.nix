# --- flake.nix
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
  description = "czichy's fully covariant tensorfiles";

  inputs = {
    # --- BASE DEPENDENCIES ---
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";

    # --- DEV DEPENDENCIES ---
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

    # --- SECRET DEPENDENCIES --
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

    # --- (NOTE, YOUR) EXTRA DEPENDENCIES --
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";

    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hardware.url = "github:NixOS/nixos-hardware/master";

    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-topology = {
      url = "github:oddlama/nix-topology";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-nftables-firewall = {
      url = "github:thelegy/nixos-nftables-firewall";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-extra-modules = {
      url = "github:czichy/nixos-extra-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #nur.url = "github:nix-community/NUR";

    arkenfox-user-js = {
      url = "github:arkenfox/user.js";
      flake = false;
    };
    nixpkgs-wayland = {
      url = "github:nix-community/nixpkgs-wayland";
      # nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-alien.url = "github:thiagokokada/nix-alien";

    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    helix = {
      url = "github:helix-editor/helix/master";
      inputs.nixpkgs.follows = "nixpkgs"; # ok?
    };
    firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";

    mcpelauncher = {
      url = "github:headblockhead/nix-mcpelauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #stylix = {
    #  url = "github:danth/stylix";
    #  inputs.nixpkgs.follows = "nixpkgs";
    #  inputs.home-manager.follows = "home-manager";
    #};
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

  outputs = inputs @ {flake-parts, ...}: let
    inherit (inputs) nixpkgs;
    inherit (lib.tensorfiles) mapModules flatten;
    self = inputs.self;
    properties = import (self + /assets/properties);
    # You should ideally use relative paths in each individual part from ./parts,
    # however, if needed you can use the `projectPath` variable that is passed
    # to every flakeModule to properly anchor your absolute paths.
    projectPath = ./.;

    # We extend the base <nixpkgs> library with our own custom helpers as well
    # as override any of the nixpkgs default functions that we'd like
    # to override. This instance is then passed to every part in ./parts so that
    # you can use it in your custom modules
    lib = nixpkgs.lib.extend (
      self: _super: {
        tensorfiles = import ./lib {
          inherit inputs projectPath;
          pkgs = nixpkgs;
          lib = self;
        };
      }
    );

    specialArgs = {
      inherit lib projectPath properties;
    };
  in
    flake-parts.lib.mkFlake {inherit inputs specialArgs;} {
      # We recursively traverse all of the flakeModules in ./parts and import only
      # the final modules, meaning that you can have an arbitrary nested structure
      # that suffices your needs. For example
      #
      # - ./parts
      #   - modules/
      #     - nixos/
      #       - myNixosModule1.nix
      #       - myNixosModule2.nix
      #       - default.nix
      #     - home-manager/
      #       - myHomeModule1.nix
      #       - myHomeModule2.nix
      #       - default.nix
      #     - sharedModules.nix
      #    - pkgs/
      #      - myPackage1.nix
      #      - myPackage2.nix
      #      - default.nix
      #    - mySimpleModule.nix
      imports = flatten (mapModules ./parts (x: x)) ++ [./parts/globals];
      # imports = flatten (mapModules ./parts (x: x));

      # NOTE We use the default `systems` defined by the `nix-systems` flake, if
      # you need any additional systems, simply add them in the following manner
      #
      # `systems = (import inputs.systems) ++ [ "armv7l-linux" ];`
      systems = import inputs.systems;
      flake.lib = lib.tensorfiles;
      # flake.lib = lib;

      # NOTE Since the official flakes output schema is unfortunately very
      # limited you can enable the debug mode if you need to inspect certain
      # outputs of your flake. Simply
      # 1. uncomment the following line
      # 2. hop into a repl from the project root - `nix repl`
      # 3. load the flake - `:lf .`
      # After that you can inspect the flake from the root attribute `debug.flake`
      #
      debug = true;
    };
}
