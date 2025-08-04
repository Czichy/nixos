{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.misc.nix;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.misc.nix = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles defaults regarding nix
      language & nix package manager.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      nix = {
        enable = _ true;
        checkConfig = _ true;
        nixPath = ["nixpkgs=${inputs.nixpkgs}"];
        package = _ pkgs.nixVersions.latest;
        registry.nixpkgs.flake = _ inputs.nixpkgs;
        settings = {
          auto-optimise-store = _ true;
          builders-use-substitutes = _ true;
          trusted-substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org/"
            "https://devenv.cachix.org"
            "https://nixpkgs-wayland.cachix.org"
            # "https://hyprland.cachix.org"
            # "https://anyrun.cachix.org"
          ];
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
            # "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            # "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
          ];
        };
        extraOptions = mkBefore ''
          experimental-features = nix-command flakes
          keep-outputs          = true
          keep-derivations      = true
        '';
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # https://github.com/NixOS/nixpkgs/issues/45492
      # Set limits for esync.
      # systemd.settings.Manager = "DefaultLimitNOFILE=1048576";
      systemd.user.extraConfig = "DefaultLimitNOFILE=32000";
      # Increase open file limit for sudoers
      security.pam.loginLimits = [
        {
          domain = "@czichy";
          item = "stack";
          type = "-";
          value = "unlimited";
        }
        {
          domain = "*";
          item = "nofile";
          type = "soft";
          value = "1048576";
        }
        {
          domain = "*";
          item = "nofile";
          type = "hard";
          value = "1048576";
        }
      ];
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
