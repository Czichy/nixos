{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation.microvm-host;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.virtualisation.microvm-host = with types; {
    enable = mkEnableOption ''
      Enables Micro-VM host.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  imports = [
    # Include the microvm host module
    inputs.microvm.nixosModules.host
  ];

  config = mkIf cfg.enable (mkMerge [
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
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = ["/var/lib/microvms"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
