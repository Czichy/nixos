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
  lib,
  options,
  ...
}: let
  inherit
    (lib)
    mkOption
    types
    ;

  defaultOptions = {
    network = mkOption {
      type = types.str;
      description = "The network to which this endpoint is associated.";
    };
  };
in {
  options = {
    globals = mkOption {
      default = {};
      type = types.submodule {
        options = {
          net = mkOption {
            type = types.attrsOf (types.submodule (netSubmod: {
              options = {
                cidrv4 = mkOption {
                  type = types.nullOr lib.tensorfiles.libNet.types.cidrv4;
                  description = "The CIDRv4 of this network";
                  default = null;
                };

                cidrv6 = mkOption {
                  type = types.nullOr lib.tensorfiles.libNet.types.cidrv6;
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
                        type = types.nullOr lib.tensorfiles.libNet.types.ipv4;
                        description = "The IPv4 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.tensorfiles.libNet.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      ipv6 = mkOption {
                        type = types.nullOr lib.tensorfiles.libNet.types.ipv6;
                        description = "The IPv6 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv6 == null
                          then null
                          else lib.tensorfiles.libNet.cidr.host hostSubmod.config.id netSubmod.config.cidrv6;
                      };

                      cidrv4 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv4 of this host including CIDR mask";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.tensorfiles.libNet.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      cidrv6 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv6 of this host including CIDR mask";
                        readOnly = true;
                        default = null;
                        # if netSubmod.config.cidrv6 == null
                        # then null
                        # else lib.tensorfiles.libNet.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv6;
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
                options =
                  defaultOptions
                  // {
                    hostv4 = mkOption {
                      type = types.nullOr types.str;
                      description = "The IP/hostname to ping via ipv4.";
                      default = null;
                    };

                    hostv6 = mkOption {
                      type = types.nullOr types.str;
                      description = "The IP/hostname to ping via ipv6.";
                      default = null;
                    };
                  };
              });
            };

            http = mkOption {
              type = types.attrsOf (types.submodule {
                options =
                  defaultOptions
                  // {
                    url = mkOption {
                      type = types.either (types.listOf types.str) types.str;
                      description = "The url to connect to.";
                    };

                    expectedStatus = mkOption {
                      type = types.int;
                      default = 200;
                      description = "The HTTP status code to expect.";
                    };

                    expectedBodyRegex = mkOption {
                      type = types.nullOr types.str;
                      description = "A regex pattern to expect in the body.";
                      default = null;
                    };

                    skipTlsVerification = mkOption {
                      type = types.bool;
                      description = "Skip tls verification when using https.";
                      default = false;
                    };
                  };
              });
            };

            dns = mkOption {
              type = types.attrsOf (types.submodule {
                options =
                  defaultOptions
                  // {
                    server = mkOption {
                      type = types.str;
                      description = "The DNS server to query.";
                    };

                    domain = mkOption {
                      type = types.str;
                      description = "The domain to query.";
                    };

                    record-type = mkOption {
                      type = types.str;
                      description = "The record type to query.";
                      default = "A";
                    };
                  };
              });
            };

            tcp = mkOption {
              type = types.attrsOf (types.submodule {
                options =
                  defaultOptions
                  // {
                    host = mkOption {
                      type = types.str;
                      description = "The IP/hostname to connect to.";
                    };

                    port = mkOption {
                      type = types.port;
                      description = "The port to connect to.";
                    };
                  };
              });
            };
          };
        };
      };
    };

    _globalsDefs = mkOption {
      type = types.unspecified;
      default = options.globals.definitions;
      readOnly = true;
      internal = true;
    };
  };
}