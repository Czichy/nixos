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
    mkUsersSettingsOption
    mkAgenixEnableOption
    ;

  _ = mkOverrideAtModuleLevel;

  cfg = config.modules.system.users;
in {
  # TODO move bluetooth dir to hardware
  options.modules.system.users = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that sets up the basis for the userspace, that is
      declarative management, basis for the home directories and also
      configures home-manager, persistence, agenix if they are enabled.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    agenix = {
      enable = mkAgenixEnableOption;
    };

    mainUser = mkOption {
      type = str;
      default = elemAt (filter (_user:cfg.usersSettings. "${_user}".isMainUser) (lib.attrNames cfg.usersSettings)) 0;
      readOnly = true;
      description = ''
        The username of the main user for your system.
        In case of a multiple systems, this will be the user with priority in ordered lists and enabled options.
      '';
    };
    # ers =
    #   genAttrs (attrNames cfg.usersSettings)
    #   (_user: let
    #     userCfg = cfg.usersSettings."${_user}".isMainUser;
    #   in {
    #     myOption = userCfg.myOption;
    #     myOtherOption = 2 * userCfg.myOtherOption;
    #   });
    usersSettings = mkUsersSettingsOption (_user: {
      isMainUser = mkOption {
        type = bool;
        default = false;
        description = ''
          The username of the main user for your system.
          In case of a multiple systems, this will be the user with priority in ordered lists and enabled options.
        '';
      };
      isSudoer = mkOption {
        type = bool;
        default = true;
        description = ''
          Add user to sudoers (ie the `wheel` group)
        '';
      };

      isNixTrusted = mkOption {
        type = bool;
        default = false;
        description = ''
          Whether the user has the ability to connect to the nix daemon
          and gain additional privileges for working with nix (like adding
          binary cache)
        '';
      };

      useHomeManager = mkOption {
        type = bool;
        default = false;
        description = ''
          use home-manager
        '';
      };

      # autoLogin = mkOption {
      #   type = bool;
      #   default = false;
      #   description = ''
      #     Whether to enable passwordless login. This is generally useful on systems with
      #     FDE (Full Disk Encryption) enabled. It is a security risk for systems without FDE.
      #   '';
      # };

      uid = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "The uid to assign if it is missing in `users.users.<name>`.";
      };
      gid = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "The gid to assign if it is missing in `users.groups.<name>`.";
      };

      extraGroups = mkOption {
        type = listOf str;
        default = [];
        description = ''
          Any additional groups which the user should be a part of. This is
          basically just a passthrough for `users.users.<user>.extraGroups`
          for convenience.
        '';
      };

      agenixPassword = {
        enable = mkEnableOption ''
          TODO
        '';

        passwordSecretsPath = mkOption {
          type = str;
          default = "hosts/${config.networking.hostName}/users/${_user}/system-password";
          description = ''
            TODO
          '';
        };
      };

      authorizedKeys = {
        enable =
          mkEnableOption ''
            TODO
          ''
          // {
            default = true;
          };

        keysRaw = mkOption {
          type = listOf str;
          default = [];
          description = ''
            TODO
          '';
        };

        keysSecretsAttrsetKey = mkOption {
          type = str;
          default = "${_user}";
          # default = "hosts.${config.networking.hostName}.users.${_user}.authorizedKeys";
          description = ''
            TODO
          '';
        };
      };
    });
  };

  # TODO ensure one or none isMainUser
  # config = {
  #   assertions = [
  #     {
  #       assertion = cfg.useHomeManager -> sys.users.mainUser != null;
  #       message = "modules.system.mainUser must be set while modules.usrEnv.useHomeManager is enabled";
  #     }
  #   ];
  # };
}
