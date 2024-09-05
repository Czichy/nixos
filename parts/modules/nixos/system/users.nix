# --- parts/modules/nixos/system/users.nix
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
  secretsPath,
  pubkeys,
}: {
  config,
  lib,
  hostName,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib.tensorfiles)
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

    usersSettings = mkUsersSettingsOption (_user: {
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

  imports = [../../../hosts/config/users.nix];
  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {users.mutableUsers = _ false;}
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
    # {
    #   users.deterministicIds = let
    #     uidGid = id: {
    #       uid = id;
    #       gid = id;
    #     };
    #   in {
    #     systemd-oom = uidGid 999;
    #     systemd-coredump = uidGid 998;
    #     sshd = uidGid 997;
    #     nscd = uidGid 996;
    #     polkituser = uidGid 995;
    #     microvm = uidGid 994;
    #     promtail = uidGid 993;
    #     grafana = uidGid 992;
    #     acme = uidGid 991;
    #     kanidm = uidGid 990;
    #     loki = uidGid 989;
    #     vaultwarden = uidGid 988;
    #     oauth2-proxy = uidGid 987;
    #     influxdb2 = uidGid 986;
    #     telegraf = uidGid 985;
    #     rtkit = uidGid 984;
    #     git = uidGid 983;
    #     redis-paperless = uidGid 982;
    #     nixseparatedebuginfod = uidGid 981;
    #     msr = uidGid 980;
    #     fwupd-refresh = uidGid 979;
    #     radicale = uidGid 978;
    #     podman = uidGid 977;
    #     maddy = uidGid 976;
    #     minecraft = uidGid 975;
    #     stalwart-mail = uidGid 974;
    #     netbird-home = uidGid 973;
    #   };
    # }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
