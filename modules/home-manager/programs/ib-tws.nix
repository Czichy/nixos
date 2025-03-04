{
  localFlake,
  inputs,
  secretsPath,
}: {
  config,
  lib,
  system,
  hostName,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    mkOverrideAtHmModuleLevel
    ;

  cfg = config.tensorfiles.hm.programs.ib-tws;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;
in {
  # TODO maybe use toINIWithGlobalSection generator? however the ini config file
  # also contains some initial keys? I should investigate this more
  options.tensorfiles.hm.programs.ib-tws = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
    # TODO maybe use config using latest and/or stable
    passwordSecretsPath = mkOption {
      type = str;
      default = "ibkr/password";
      description = ''
        TODO
      '';
    };

    userSecretsPath = mkOption {
      type = str;
      default = "ibkr/user";
      description = ''
        TODO
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = [
        inputs.self.packages.${system}.ib-tws-native
        inputs.self.packages.${system}.ib-tws-native-latest
      ];
    }
    # |----------------------------------------------------------------------| #
    (
      mkIf agenixCheck
      {
        age.secrets = {
          "${cfg.userSecretsPath}" = {
            # symlink = true;
            file = _ (secretsPath + "/${cfg.userSecretsPath}.age");
            mode = _ "0600";
          };
          "${cfg.passwordSecretsPath}" = {
            # symlink = true;
            file = _ (secretsPath + "/${cfg.passwordSecretsPath}.age");
            mode = _ "0600";
          };
        };
      }
    )
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        allowOther = true;
        directories = [
          ".ib-tws-native"
          ".tws-latest"
          ".ib-tws-native_latest"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
