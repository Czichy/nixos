# --- parts/secrets/default.nix
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
  config,
  lib,
  self,
  inputs,
  ...
}: let
  localFlake = self;
in {
  options.secrets = with lib.types; {
    secretsPath = lib.mkOption {
      type = path;
      default = "${inputs.private}";
      #default = ./secrets;
      description = "Path to the actual secrets directory";
    };

    pubkeys = lib.mkOption {
      type = attrsOf (attrsOf anything);
      default = {};
      description = ''
        The resulting option that will hold the various public keys used around
        the flake.
      '';
    };

    pubkeysFile = lib.mkOption {
      type = path;
      default = ./pubkeys.nix;
      description = ''
        Path to the pubkeys file that will be used to construct the
        `secrets.pubkeys` option.
      '';
    };

    extraPubkeys = lib.mkOption {
      type = attrsOf (attrsOf anything);
      default = {};
      description = ''
        Additional public keys that will be merged into the `secrets.pubkeys`
      '';
    };
  };

  config = {
    secrets.pubkeys = (import config.secrets.pubkeysFile) // config.secrets.extraPubkeys;
    secrets.secretsPath = "${inputs.private}";

    flake.nixosModules.security_agenix = {
      config,
      lib,
      pkgs,
      system,
      ...
    }:
      with builtins;
      with lib; let
        cfg = config.tensorfiles.security.agenix;
      in {
        options.tensorfiles.security.agenix = with types; {
          enable = mkEnableOption ''
            Enables NixOS module that sets up & configures the agenix secrets
            backend.

            References
            - https://github.com/ryantm/agenix
            - https://nixos.wiki/wiki/Agenix
          '';
        };

        imports = with inputs; [agenix.nixosModules.default];

        config = mkIf cfg.enable {
          environment.systemPackages = [
            inputs.agenix.packages.${system}.default
            pkgs.age
          ];

          age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        };

        meta.maintainers = with localFlake.lib.maintainers; [czichy];
      };

    flake.homeModules.security_agenix = {
      config,
      lib,
      ...
    }:
      with builtins;
      with lib; let
        cfg = config.tensorfiles.hm.security.agenix;
      in {
        options.tensorfiles.hm.security.agenix = with types; {
          enable = mkEnableOption ''
            Enable Home Manager module that sets up & configures the agenix
            secrets backend.

            References
            - https://github.com/ryantm/agenix
            - https://nixos.wiki/wiki/Agenix
          '';

          secretsPath = lib.mkOption {
            type = path;
            default = "${inputs.private}";
            #default = ./secrets;
            description = "Path to the actual secrets directory";
          };
        };

        imports = with inputs; [
          # agenix.homeManagerModules.default
          agenix.homeManagerModules.age
        ];

        config = mkIf cfg.enable {
          age.identityPaths = [
            "${config.home.homeDirectory}/.ssh/id_ed25519"
            "${config.home.homeDirectory}/.ssh/czichy_desktop_ed25519"
          ];
        };

        meta.maintainers = with localFlake.lib.maintainers; [czichy];
      };
  };
}
