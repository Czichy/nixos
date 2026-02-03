{
  localFlake,
  inputs,
}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  # inherit (localFlake.lib) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.system.impermanence;
in
  # _ = mkOverrideAtHmModuleLevel;
  {
    options.tensorfiles.hm.system.impermanence = with types; {
      enable = mkEnableOption ''
        TODO
      '';

      persistentRoot = mkOption {
        type = path;
        default = "/persist";
        description = ''
          Path on the already mounted filesystem for the persistent root, that is,
          a root where we should store the persistent files and against which should
          we link the temporary files against.

          This is usually simply just /persist.
        '';
      };


    };



    config = mkIf cfg.enable (mkMerge [
      # |----------------------------------------------------------------------| #
      {
        assertions = [
          {
            assertion = hasAttr "impermanence" inputs;
            message = "Impermanence flake missing in the inputs library. Please add it to your flake inputs.";
          }
        ];
      }
      # |----------------------------------------------------------------------| #
      {

      }
      # |----------------------------------------------------------------------| #
    ]);

    meta.maintainers = with localFlake.lib.maintainers; [czichy];
  }
