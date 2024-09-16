{
  localFlake,
  secretsPath,
  pubkeys,
}: {
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtModuleLevel
    isModuleLoadedAndEnabled
    mapToAttrsAndMerge
    mkImpermanenceEnableOption
    mkUsersSettingsOption
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.system.users;
  _ = mkOverrideAtModuleLevel;

  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  # TODO move bluetooth dir to hardware
  options.tensorfiles.system.users = with types; {
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

    deterministicIds = mkOption {
      default = {};
      description = ''
        Maps a user or group name to its expected uid/gid values. If a user/group is
        used on the system without specifying a uid/gid, this module will assign the
        corresponding ids defined here, or show an error if the definition is missing.
      '';
      type = types.attrsOf (types.submodule {
        options = {
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
        };
      });
    };

    users = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        config.uid = let
          deterministicUid = cfg.${name}.uid or null;
        in
          mkIf (deterministicUid != null) (mkDefault deterministicUid);
      }));
    };

    groups = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        config.gid = let
          deterministicGid = cfg.${name}.gid or null;
        in
          mkIf (deterministicGid != null) (mkDefault deterministicGid);
      }));
    };

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
          default = "hosts/${hostName}/users/${_user}/system-password";
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
          default = "hosts.${hostName}.users.${_user}.authorizedKeys";
          description = ''
            TODO
          '';
        };
      };
    });
  };

  imports = [
    ./czichy.nix
    ./deterministic-ids.nix
    ./root.nix
  ];
  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      users = {
        mutableUsers = _ false;
        allowNoPasswordLogin = _ false;
        enforceIdUniqueness = _ true;
        defaultUserShell = pkgs.nushell;
      };
    }
    # |----------------------------------------------------------------------| #
    {
      users.users = genAttrs (attrNames cfg.usersSettings) (
        _user: let
          userCfg = cfg.usersSettings."${_user}";
        in {
          name = _ _user;
          isNormalUser = _ (_user != "root");
          isSystemUser = _ (_user == "root");
          uid = userCfg.uid;
          group = _user;
          autoSubUidGidRange = false;
          createHome = _ true;
          extraGroups = (optional (_user != "root" && userCfg.isSudoer) "wheel") ++ userCfg.extraGroups;
          home = _ (
            if _user == "root"
            then "/root"
            else "/home/${_user}"
          );

          hashedPasswordFile = mkIf (agenixCheck && userCfg.agenixPassword.enable) (
            _ config.age.secrets.${userCfg.agenixPassword.passwordSecretsPath}.path
          );
          # initialPassword = "nixos";

          openssh.authorizedKeys.keys = with userCfg.authorizedKeys; (mkIf enable (
            keysRaw ++ (attrsets.attrByPath (splitString "." keysSecretsAttrsetKey) [] pubkeys)
          ));
        }
      );
    }
    # |----------------------------------------------------------------------| #
    {
      users.groups = mapToAttrsAndMerge (attrNames cfg.usersSettings) (
        _user: let
          userCfg = cfg.usersSettings."${_user}";
        in {
          ${_user}.gid = userCfg.gid;
        }
      );
    }
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets = mapToAttrsAndMerge (attrNames cfg.usersSettings) (
        _user: let
          userCfg = cfg.usersSettings."${_user}";
        in
          with userCfg.agenixPassword; {
            "${passwordSecretsPath}" = mkIf enable {
              file = _ (secretsPath + "/${passwordSecretsPath}.age");
              mode = _ "700";
              owner = _ _user;
            };
          }
      );
    })
    # |----------------------------------------------------------------------| #
    {
      nix.settings = let
        users = filter (_user: cfg.usersSettings."${_user}".isNixTrusted) (attrNames cfg.usersSettings);
      in {
        trusted-users = users;
        allowed-users = users;
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # assertions =
      #   concatLists (flip mapAttrsToList config.users.users (name: user: [
      #     {
      #       assertion = user.uid != null;
      #       message = "non-deterministic uid detected for '${name}', please assign one via `users.deterministicIds`";
      #     }
      #     {
      #       assertion = !user.autoSubUidGidRange;
      #       message = "non-deterministic subUids/subGids detected for: ${name}";
      #     }
      #   ]))
      #   ++ flip mapAttrsToList config.users.groups (name: group: {
      #     assertion = group.gid != null;
      #     message = "non-deterministic gid detected for '${name}', please assign one via `users.deterministicIds`";
      #   });
    }
    # |----------------------------------------------------------------------| #
  ]);
}
