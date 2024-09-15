{
  config,
  inputs,
  lib,
  ...
}:
with lib; let
  inherit (lib.modules) mkIf;
  inherit (lib) mkOverrideAtModuleLevel;
  sys = config.modules.system;
  fp = sys.services.flatpak;

  _ = mkOverrideAtModuleLevel;
  impermanenceCheck = sys.impermanence.root.enable;

  impermanence =
    if impermanenceCheck
    then sys.impermanence
    else {};
in {
  imports = [inputs.nix-flatpak.nixosModules.nix-flatpak];

  config = mkIf fp.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      # enable flatpak, as well as xdgp to communicate with the host filesystems
      services.flatpak.enable = _ true;

      services.flatpak.packages = fp.packages;
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
    {environment.sessionVariables.XDG_DATA_DIRS = ["/var/lib/flatpak/exports/share"];}
  ]);
}
