# --- parts/secrets/default.nix
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
  lib,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    options
    types
    mkOverrideAtModuleLevel
    isModuleLoadedAndEnabled
    mapToAttrsAndMerge
    mkImpermanenceEnableOption
    mkUsersSettingsOption
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.globals;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.globals = mkOption {
    default = {};
    type = types.submodule {
      options = {
        net = mkOption {
          type = types.attrsOf (types.submodule (netSubmod: {
            options = {
              cidrv4 = mkOption {
                type = types.nullOr lib.libNet.types.cidrv4;
                description = "The CIDRv4 of this network";
                default = null;
              };

              cidrv6 = mkOption {
                type = types.nullOr lib.libNet.types.cidrv6;
                description = "The CIDRv6 of this network";
                default = null;
              };

              hosts = mkOption {
                type = types.attrsOf (types.submodule (hostSubmod: {
                  options = {
                    id = mkOption {
                      type = types.int;
                      description = "The id of this host in the network";
                    };

                    ipv4 = mkOption {
                      type = types.nullOr lib.libNet.types.ipv4;
                      description = "The IPv4 of this host";
                      readOnly = true;
                      default =
                        if netSubmod.config.cidrv4 == null
                        then null
                        else lib.libNet.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
                    };

                    ipv6 = mkOption {
                      type = types.nullOr lib.libNet.types.ipv6;
                      description = "The IPv6 of this host";
                      readOnly = true;
                      default =
                        if netSubmod.config.cidrv6 == null
                        then null
                        else lib.libNet.cidr.host hostSubmod.config.id netSubmod.config.cidrv6;
                    };

                    cidrv4 = mkOption {
                      type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                      description = "The IPv4 of this host including CIDR mask";
                      readOnly = true;
                      default = null;
                      # if netSubmod.config.cidrv4 == null
                      # then null
                      # else lib.libNet.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
                    };

                    cidrv6 = mkOption {
                      type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                      description = "The IPv6 of this host including CIDR mask";
                      readOnly = true;
                      default = null;
                      # if netSubmod.config.cidrv6 == null
                      # then null
                      # else lib.libNet.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv6;
                    };
                  };
                }));
              };
            };
          }));
        };

        services = mkOption {
          type = types.attrsOf (types.submodule {
            options = {
              domain = mkOption {
                type = types.str;
                description = "The domain under which this service can be reached";
              };
            };
          });
        };

        monitoring = {
          ping = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                fromNetwork = mkOption {
                  type = types.str;
                  description = "The network from which this service is reachable.";
                  default = "external";
                };
              };
            });
          };
        };
      };
    };
  };

  # # _globalsDefs = mkOption {
  # #   type = types.unspecified;
  # #   default = options.globals.definitions;
  # #   readOnly = true;
  # #   internal = true;
  # # };

  # config = {
  #   globals.net = {
  #     home-wan = {
  #       cidrv4 = "192.168.178.0/24";
  #       hosts.fritzbox.id = 1;
  #       hosts.ward.id = 2;
  #     };

  #     home-lan = {
  #       cidrv4 = "192.168.1.0/24";
  #       cidrv6 = "fd10::/64";
  #       hosts.ward.id = 1;
  #       hosts.sire.id = 2;
  #       hosts.ward-adguardhome.id = 3;
  #       hosts.ward-web-proxy.id = 4;
  #       hosts.sire-samba.id = 10;
  #     };

  #     v-lan = {
  #       cidrv4 = "192.168.122.0/24";
  #       cidrv6 = "fd10::/64";
  #       hosts.ward.id = 175;
  #       hosts.sire.id = 2;
  #       hosts.ward-adguardhome.id = 3;
  #       hosts.ward-web-proxy.id = 4;
  #       hosts.sire-samba.id = 10;
  #     };

  #     proxy-home = {
  #       cidrv4 = "10.44.0.0/24";
  #       cidrv6 = "fd00:44::/120";
  #     };
  #   };
  # };
}
