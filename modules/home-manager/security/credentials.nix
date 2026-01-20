{
  localFlake,
  secretsPath,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.security.credentials;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.security.credentials = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      age.secrets.ledger_secrets = {
        file = _ (secretsPath + "/hosts/HL-1-OZ-PC-01/users/czichy/ledger/secrets.yaml.age");
        mode = _ "700";
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
