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
{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  _ = mkOverrideAtModuleLevel;
  nodeName = config.tensorfiles.node.name;
  mkForwardedOption = path:
    mkOption {
      type = mkOptionType {
        name = "Same type that the receiving option `${concatStringsSep "." path}` normally accepts.";
        merge = _loc: defs:
          builtins.filter
          (x: builtins.isAttrs x -> ((x._type or "") != "__distributed_config_empty"))
          (map (x: x.value) defs);
      };
      default = {_type = "__distributed_config_empty";};
      description = ''
        Anything specified here will be forwarded to `${concatStringsSep "." path}`
        on the given node. Forwarding happens as-is to the raw values,
        so validity can only be checked on the receiving node.
      '';
    };

  forwardedOptions = [
    ["age" "secrets"]
    ["networking" "nftables" "chains"]
    ["services" "nginx" "upstreams"]
    ["services" "nginx" "virtualHosts"]
    ["services" "influxdb2" "provision" "organizations"]
    ["services" "kanidm" "provision" "groups"]
    ["services" "kanidm" "provision" "systems" "oauth2"]
  ];

  attrsForEachOption = f: foldl' (acc: path: recursiveUpdate acc (setAttrByPath path (f path))) {} forwardedOptions;
in {
  options.nodes = mkOption {
    description = "Options forwareded to the given node.";
    default = {};
    type = types.attrsOf (types.submodule {
      options = attrsForEachOption mkForwardedOption;
    });
  };

  config = let
    getConfig = path: otherNode: let
      cfg = nodes.${otherNode}.config.nodes.${nodeName} or null;
    in
      optionals (cfg != null) (getAttrFromPath path cfg);
    mergeConfigFromOthers = path: mkMerge (concatMap (getConfig path) (attrNames nodes));
  in
    attrsForEachOption mergeConfigFromOthers;
}
