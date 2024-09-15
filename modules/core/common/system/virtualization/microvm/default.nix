{
  config,
  lib,
  pkgs,
  pubkeys,
  inputs,
  # utils,
  ...
} @ attrs: let
  inherit (lib) isModuleLoadedAndEnabled mergeToplevelConfigs;
  cfg = config.modules.system.services.microvm;
  sys = config.modules.system;

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
  impermanenceCheck = sys.impermanence.root.enable;
  impermanence =
    if impermanenceCheck
    then sys.impermanence
    else {};
in {
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
          directories = ["/var/lib/microvms"];
        };
      })
      # |----------------------------------------------------------------------| #
    ]
  );
}
