{
  localFlake,
  pubkeys,
}: {
  config,
  lib,
  pkgs,
  pubkeys,
  inputs,
  self,
  # utils,
  ...
} @ attrs: let
  inherit
    (lib)
    mkOption
    types
    ;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption mergeToplevelConfigs mapAttrsToList;
  cfg = config.tensorfiles.services.microvm;

  generateMacAddress = s: let
    hash = builtins.hashString "sha256" s;
    c = off: builtins.substring off 2 hash;
  in "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

  # List the necessary mount units for the given guest
  fsMountUnitsFor = guestCfg: map (x: x.hostMountpoint) (lib.attrValues guestCfg.zfs);

  defineMicrovm = guestName: guestCfg: {
    # Ensure that the zfs dataset exists before it is mounted.
    # systemd.services."microvm@${guestName}" = {
    #   unitConfig = {
    #     RequiresMountsFor = fsMountUnitsFor guestCfg;
    #   };
    # };

    microvm.vms.${guestName} = import ./microvm.nix guestName guestCfg attrs;
  };
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.microvm = {
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
                type = localFlake.lib.net.types.mac;
                description = "The base mac address from which the guest's mac will be derived. Only the second and third byte are used, so for 02:XX:YY:ZZ:ZZ:ZZ, this specifies XX and YY, while Zs are generated automatically. Not used if the mac is set directly.";
                default = "02:01:27:00:00:00";
              };

              mac = lib.mkOption {
                type = localFlake.lib.net.types.mac;
                description = "The MAC address for the guest's macvtap interface";
                default = let
                  base = "02:${lib.substring 3 5 submod.config.microvm.baseMac}:00:00:00";
                in
                  (localFlake.lib.net.mac.assignMacs base 24 [] (lib.attrNames cfg.guests)).${submod.config._module.args.name};
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

  # imports = [inputs.microvm.nixosModules.host];
  config = lib.mkIf (cfg.enable && cfg.guests != {}) (
    lib.mkMerge [
      # |----------------------------------------------------------------------| #
      {
        systemd.tmpfiles.rules = ["d /guests 0700 root root -"];

        # modules.zfs.datasets.properties = let
        #   zfsDefs = lib.flatten (
        #     lib.flip lib.mapAttrsToList cfg.guests (
        #       _: guestCfg:
        #         lib.flip lib.mapAttrsToList guestCfg.zfs (
        #           _: zfsCfg: {
        #             dataset = "${zfsCfg.dataset}";
        #             inherit (zfsCfg) hostMountpoint;
        #           }
        #         )
        #     )
        #   );
        #   zfsAttrSet = lib.listToAttrs (
        #     map (zfsDef: {
        #       name = zfsDef.dataset;
        #       value = {
        #         mountpoint = zfsDef.hostMountpoint;
        #       };
        #     })
        #     zfsDefs
        #   );
        # in
        #   zfsAttrSet;
        # assertions = lib.flatten (
        #   lib.flip lib.mapAttrsToList cfg.guests (
        #     guestName: guestCfg:
        #       lib.flip lib.mapAttrsToList guestCfg.zfs (
        #         zfsName: zfsCfg: {
        #           assertion = lib.hasPrefix "/" zfsCfg.guestMountpoint;
        #           message = "guest ${guestName}: zfs ${zfsName}: the guestMountpoint must be an absolute path.";
        #         }
        #       )
        #   )
        # );
      }
      # |----------------------------------------------------------------------| #
      (mergeToplevelConfigs [
        "microvm"
        "systemd"
      ] (lib.mapAttrsToList defineMicrovm cfg.guests))
      # |----------------------------------------------------------------------| #
      {
        # environment.etc."machine-id" = {
        #   mode = "0644";
        #   text =
        #     # change this to suit your flake's interface
        #     self.lib.addresses.machineId.${config.networking.hostName} + "\n";
        # };
        # systemd.tmpfiles.rules = map (
        #   vmHost: let
        #     machineId = self.lib.addresses.machineId.${vmHost};
        #   in
        #     # creates a symlink of each MicroVM's journal under the host's /var/log/journal
        #     "L+ /var/log/journal/${machineId} - - - - /var/lib/microvms/${vmHost}/journal/${machineId}"
        # ) (builtins.attrNames self.lib.addresses.machineId);
      }
      # |----------------------------------------------------------------------| #
      (lib.mkIf impermanenceCheck {
        environment.persistence."${impermanence.persistentRoot}" = {
          directories = ["/var/lib/microvms" "/etc/vm-persist"];
        };
      })
      # |----------------------------------------------------------------------| #
    ]
  );
  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
