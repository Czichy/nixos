# --- parts/modules/home-manager/services/keepassxc.nix
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
  localFlake,
  inputs,
  secretsPath,
}: {
  config,
  lib,
  system,
  hostName,
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
          ".ib-tws-native_latest"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
