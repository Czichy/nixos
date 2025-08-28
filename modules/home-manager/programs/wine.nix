{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  # inherit (localFlake.lib) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.programs.wine;
in {
  options.tensorfiles.hm.programs.wine = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        # support 64-bit only
        wine64

        # winetricks (all versions)
        winetricks

        # native wayland support (unstable)
        wineWowPackages.waylandFull
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        allowOther = true;
        directories = [
          ".wine"
          ".cache/wine"
          ".cache/winetricks"
          ".local/share/applications/wine"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
