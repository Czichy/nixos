{
  config,
  lib,
  pkgs,
  pubkeys,
  ...
}:
with builtins;
with lib; let
  inherit
    (lib)
    mkOverrideAtModuleLevel
    isModuleLoadedAndEnabled
    mapToAttrsAndMerge
    ;

  sys = config.modules.system;
  cfg = sys.users;
  _ = mkOverrideAtModuleLevel;

  agenixCheck = sys.agenix.enable;
in {
  imports = [
    # ../../../hosts/config/users.nix
    ./czichy.nix
    ./deterministic_ids.nix
    # ./builder.nix
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
              file = _ (sys.agenix.root.secretsPath + "/${passwordSecretsPath}.age");
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
  ]);
}
# {pkgs, ...}: {
#   # We want to handle user configurations on a per-file basis. What that
#   # means is a new user cannot be added via, e.g., useradd unless a new
#   # file has been added here to create user configuration.
#   # In short:users that are not in users/<username>.nix don't get to
#   # be a real user
#   imports = [
#     ./czichy.nix
#     ./builder.nix
#     ./root.nix
#   ];
#   config = {
#     users = {
#       # Default user shell package
#       defaultUserShell = pkgs.zsh;
#       # And other stuff...
#       allowNoPasswordLogin = false;
#       enforceIdUniqueness = true;
#     };
#   };
# }

