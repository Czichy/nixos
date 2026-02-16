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
      age.secrets = {
        ledger_secrets = {
          file = _ (secretsPath + "/hosts/HL-1-OZ-PC-01/users/czichy/ledger/secrets.yaml.age");
          mode = _ "700";
        };
        ibkr_user = {
          file = _ (secretsPath + "/ibkr/user.age");
          mode = _ "700";
        };
        ibkr_password = {
          file = _ (secretsPath + "/ibkr/password.age");
          mode = _ "700";
        };
        ibkr_paper_user = {
          file = _ (secretsPath + "/ibkr/paper-user.age");
          mode = _ "700";
        };
        ibkr_paper_password = {
          file = _ (secretsPath + "/ibkr/paper-password.age");
          mode = _ "700";
        };
        massive_api_key = {
          file = _ (secretsPath + "/massive/api-key.age");
          mode = _ "700";
        };
        massive_file_access_key = {
          file = _ (secretsPath + "/massive/files-access-key.age");
          mode = _ "700";
        };
        massive_file_secret_key = {
          file = _ (secretsPath + "/massive/files-secret-key.age");
          mode = _ "700";
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
