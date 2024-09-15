{lib, ...}:
with builtins;
with lib; let
  inherit
    (lib)
    mkImpermanenceEnableOption
    ;
  packageOptions = _: {
    options = {
      appId = mkOption {
        type = types.str;
        description = lib.mdDoc "The fully qualified id of the app to install.";
      };

      commit = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc "Hash id of the app commit to install.";
        default = null;
      };

      origin = mkOption {
        type = types.str;
        default = "flathub";
        description = lib.mdDoc "App repository origin (default: flathub).";
      };
    };
  };
in {
  options.modules.system.services.flatpak = {
    enable = mkEnableOption "Flatpak Package Manager";
    impermanence.enable = mkImpermanenceEnableOption;
    packages = mkOption {
      type = with types; listOf (coercedTo str (appId: {inherit appId;}) (submodule packageOptions));
      default = [];
      description = lib.mdDoc ''
        Declares a list of applications to install.
      '';
      example = literalExpression ''
        [
            # declare applications to install using its fqdn
            "com.obsproject.Studio"
            # specify a remote.
            { appId = "com.brave.Browser"; origin = "flathub";  }
            # Pin the application to a specific commit.
            { appId = "im.riot.Riot"; commit = "bdcc7fff8359d927f25226eae8389210dba3789ca5d06042d6c9c133e6b1ceb1" }
        ];
      '';
    };
  };
}
