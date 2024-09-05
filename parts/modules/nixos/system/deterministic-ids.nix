# --- parts/modules/nixos/misc/node.nix
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
{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatLists
    flip
    mapAttrsToList
    mkDefault
    mkIf
    mkOption
    types
    ;

  cfg = config.users.deterministicIds;
in {
  options = {
    users.deterministicIds = mkOption {
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

    users.users = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        config.uid = let
          deterministicUid = cfg.${name}.uid or null;
        in
          mkIf (deterministicUid != null) (mkDefault deterministicUid);
      }));
    };

    users.groups = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        config.gid = let
          deterministicGid = cfg.${name}.gid or null;
        in
          mkIf (deterministicGid != null) (mkDefault deterministicGid);
      }));
    };
  };

  config = {
    assertions =
      concatLists (flip mapAttrsToList config.users.users (name: user: [
        {
          assertion = user.uid != null;
          message = "non-deterministic uid detected for '${name}', please assign one via `users.deterministicIds`";
        }
        {
          assertion = !user.autoSubUidGidRange;
          message = "non-deterministic subUids/subGids detected for: ${name}";
        }
      ]))
      ++ flip mapAttrsToList config.users.groups (name: group: {
        assertion = group.gid != null;
        message = "non-deterministic gid detected for '${name}', please assign one via `users.deterministicIds`";
      });
  };
}
