{
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit
    (lib)
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    ;
in {
  # TODO maybe use toINIWithGlobalSection generator? however the ini config file
  # also contains some initial keys? I should investigate this more
  options.modules.system.programs.ib-tws = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
    # # TODO maybe use config using latest and/or stable
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
}
