{
  config,
  lib,
  ...
} @ attrs: let
  inherit
    (lib)
    mkOption
    types
    ;
  inherit (lib) mkImpermanenceEnableOption;
  cfg = config.modules.system.services.microvm;
in {
  options.modules.system.services.microvm = {
    enable = lib.mkEnableOption "microvm";
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    guests = lib.mkOption {
      default = {};
      description = "Defines the actual vms and handles the necessary base setup for them.";
      type = lib.types.attrsOf (
        lib.types.submodule (submod: {
          options = {
            nodeName = lib.mkOption {
              type = lib.types.str;
              default = "${config.networking.hostName}-${submod.config._module.args.name}";
              description = ''
                The name of the resulting node. By default this will be a compound name
                of the host's name and the guest's name to avoid name clashes. Can be
                overwritten to designate special names to specific guests.
              '';
            };

            extraSpecialArgs = lib.mkOption {
              type = lib.types.attrs;
              default = {};
              example = lib.literalExpression "{ inherit inputs; }";
              description = ''
                Extra `specialArgs` passed to each guest system definition. This
                option can be used to pass additional arguments to all modules.
              '';
            };

            # Options for the microvm backend
            microvm = {
              system = lib.mkOption {
                type = lib.types.str;
                description = "The system that this microvm should use";
              };

              macvtap = lib.mkOption {
                type = lib.types.str;
                description = "The host interface to which the microvm should be attached via macvtap";
              };

              baseMac = lib.mkOption {
                type = lib.types.net.mac;
                description = "The base mac address from which the guest's mac will be derived. Only the second and third byte are used, so for 02:XX:YY:ZZ:ZZ:ZZ, this specifies XX and YY, while Zs are generated automatically. Not used if the mac is set directly.";
                default = "02:01:27:00:00:00";
              };

              mac = lib.mkOption {
                type = lib.types.net.mac;
                description = "The MAC address for the guest's macvtap interface";
                default = let
                  base = "02:${lib.substring 3 5 submod.config.microvm.baseMac}:00:00:00";
                in
                  (lib.net.mac.assignMacs base 24 [] (lib.attrNames cfg.guests)).${submod.config._module.args.name};
              };
            };

            networking = {
              mainLinkName = lib.mkOption {
                type = lib.types.str;
                description = "The main ethernet link name inside of the guest.";
                default = submod.config.microvm.macvtap;
              };
              address = lib.mkOption {
                description = "The CIDRv4 of the guest";
                default = null;
                type = lib.types.str;
              };
              gateway = lib.mkOption {
                type = lib.types.str;
                description = "The gateway of the guest";
              };
              # dns = lib.mkOption {
              #   type = lib.types.listOf lib.types.str;
              #   description = "The DNS servers of the guest";
              # };
            };

            zfs = lib.mkOption {
              description = "zfs datasets to mount into the guest";
              default = {};
              type = lib.types.attrsOf (
                lib.types.submodule (zfsSubmod: {
                  options = {
                    pool = lib.mkOption {
                      type = lib.types.str;
                      description = "The host's zfs pool on which the dataset resides";
                    };

                    dataset = lib.mkOption {
                      type = lib.types.str;
                      example = "rpool/encrypted/safe/vms/myvm";
                      description = "The host's dataset that should be used for this mountpoint (will automatically be created, including parent datasets)";
                    };

                    hostMountpoint = lib.mkOption {
                      type = lib.types.path;
                      default = "/guests/${submod.config._module.args.name}${zfsSubmod.config.guestMountpoint}";
                      example = "/guests/mycontainer/persist";
                      description = "The host's mountpoint for the guest's dataset";
                    };

                    guestMountpoint = lib.mkOption {
                      type = lib.types.path;
                      default = zfsSubmod.config._module.args.name;
                      example = "/persist";
                      description = "The mountpoint inside the guest.";
                    };
                  };
                })
              );
            };

            autostart = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this guest should be started automatically with the host";
            };

            modules = lib.mkOption {
              type = lib.types.listOf lib.types.unspecified;
              default = [];
              description = "Additional modules to load";
            };
          };
        })
      );
    };
  };
}
