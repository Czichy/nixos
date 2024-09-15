{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption;

  cfg = config.modules.system.agenix;
in {
  options.modules.system.agenix = with lib.types; {
    enable = mkOption {
      default = cfg.root.enable || cfg.home.enable;
      readOnly = true;
      description = ''
        Internal option for deciding if Impermanence module is enabled
        based on the values of `modules.system.impermanence.root.enable`
        and `modules.system.impermanence.home.enable`.
      '';
    };
    root = {
      enable =
        mkEnableOption ''
        '';
      secretsPath = mkOption {
        type = path;
        default = "${inputs.private}";
        #default = ./secrets;
        description = "Path to the actual secrets directory";
      };

      pubkeys = mkOption {
        type = attrsOf (attrsOf anything);
        default = {};
        description = ''
          The resulting option that will hold the various public keys used around
          the flake.
        '';
      };

      pubkeysFile = mkOption {
        type = path;
        default = ./pubkeys.nix;
        description = ''
          Path to the pubkeys file that will be used to construct the
          `secrets.pubkeys` option.
        '';
      };

      extraPubkeys = mkOption {
        type = attrsOf (attrsOf anything);
        default = {};
        description = ''
          Additional public keys that will be merged into the `secrets.pubkeys`
        '';
      };
    };
    home = {
      enable =
        mkEnableOption ''
        '';
      secretsPath = mkOption {
        type = path;
        default = "${inputs.private}";
        #default = ./secrets;
        description = "Path to the actual secrets directory";
      };

      pubkeys = mkOption {
        type = attrsOf (attrsOf anything);
        default = {};
        description = ''
          The resulting option that will hold the various public keys used around
          the flake.
        '';
      };

      pubkeysFile = mkOption {
        type = path;
        default = ./pubkeys.nix;
        description = ''
          Path to the pubkeys file that will be used to construct the
          `secrets.pubkeys` option.
        '';
      };

      extraPubkeys = mkOption {
        type = attrsOf (attrsOf anything);
        default = {};
        description = ''
          Additional public keys that will be merged into the `secrets.pubkeys`
        '';
      };
    };
  };
}
