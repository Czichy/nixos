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
  inherit (localFlake.lib) mkOverrideAtModuleLevel;
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;
  cfg = config.tensorfiles.services.flatpak;
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;

  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.services.flatpak = with types; {
    enable = mkEnableOption ''

      Enables NixOS module that sets up the basis for the userspace, that is
      declarative management, basis for the home directories and also
      configures home-manager, persistence, agenix if they are enabled.
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      services.flatpak.enable = _ true;

      # Minecraft
      # Minecraft bedrock
      services.flatpak.packages = [
        "io.mrarm.mcpelauncher"
      ];
      xdg.portal = {
        enable = true;
        wlr.enable = true;
        config.common.default = "*";
      };
    }
    # |----------------------------------------------------------------------| #
    (lib.mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = ["/var/lib/flatpak"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
