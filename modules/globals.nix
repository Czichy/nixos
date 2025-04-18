{
  lib,
  options,
  ...
}: let
  # inherit lib;
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
                  type = types.nullOr lib.net.types.cidrv4;
                  description = "The CIDRv4 of this network";
                  default = null;
                };

                cidrv6 = mkOption {
                  type = types.nullOr lib.net.types.cidrv6;
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
                        type = types.nullOr lib.net.types.ipv4;
                        description = "The IPv4 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      ipv6 = mkOption {
                        type = types.nullOr lib.net.types.ipv6;
                        description = "The IPv6 of this host";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv6 == null
                          then null
                          else lib.net.cidr.host hostSubmod.config.id netSubmod.config.cidrv6;
                      };

                      cidrv4 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv4 of this host including CIDR mask";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv4 == null
                          then null
                          else lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv4;
                      };

                      cidrv6 = mkOption {
                        type = types.nullOr types.str; # FIXME: this is not types.net.cidr because it would zero out the host part
                        description = "The IPv6 of this host including CIDR mask";
                        readOnly = true;
                        default =
                          if netSubmod.config.cidrv6 == null
                          then null
                          else lib.net.cidr.hostCidr hostSubmod.config.id netSubmod.config.cidrv6;
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
          mail = {
            domains = mkOption {
              default = {};
              description = "All domains on which we receive mail.";
              type = types.attrsOf (types.submodule {
                options = {
                  public = mkOption {
                    type = types.bool;
                    description = "Whether the domain should be available for use by any user";
                  };
                };
              });
            };

            primary = mkOption {
              type = types.str;
              description = "The primary mail domain.";
            };
          };

          domains = {
            me = mkOption {
              type = types.str;
              description = "My main domain.";
            };

            personal = mkOption {
              type = types.str;
              description = "My personal domain.";
            };

            local = mkOption {
              type = types.str;
              description = "My personal domain.";
            };
          };

          macs = mkOption {
            default = {};
            type = types.attrsOf types.str;
            description = "Known MAC addresses for external devices.";
          };

          # Mirror of the kanidm.persons option.
          kanidm.persons = mkOption {
            description = "Provisioning of kanidm persons";
            default = {};
            type = types.attrsOf (types.submodule {
              options = {
                displayName = mkOption {
                  description = "Display name";
                  type = types.str;
                };

                legalName = mkOption {
                  description = "Full legal name";
                  type = types.nullOr types.str;
                  default = null;
                };

                mailAddresses = mkOption {
                  description = "Mail addresses. First given address is considered the primary address.";
                  type = types.listOf types.str;
                  default = [];
                };

                groups = mkOption {
                  description = "List of groups this person should belong to.";
                  type = types.listOf types.str;
                  default = [];
                };
              };
            });
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
