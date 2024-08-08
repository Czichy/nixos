# --- parts/modules/nixos/system/flatpak.nix
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
}:
with builtins;
with lib; let
  inherit (localFlake.lib.tensorfiles) mkOverrideAtModuleLevel;
  inherit (localFlake.lib.tensorfiles) isModuleLoadedAndEnabled mkImpermanenceEnableOption;
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

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
