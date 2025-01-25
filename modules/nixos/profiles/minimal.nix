{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.minimal;
  _ = mkOverrideAtProfileLevel;
in {
  options.tensorfiles.profiles.minimal = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the minimal system profile.

      **Minimal layers** builds on top of the base layer and creates a
      minimal bootable system. It isn't targeted to posses any other functionality,
      for example if you'd like remote access and more of server-like features,
      use the headless profile that build on top of this one.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles = {
        profiles.base.enable = _ true;

        system.users.enable = _ true;
        misc.nix.enable = _ true;
        tasks.nix-garbage-collect.enable = _ true;
        tasks.system-autoupgrade.enable = _ true;
      };

      time.timeZone = _ "Europe/Berlin";
      i18n.defaultLocale = _ "de_DE.UTF-8";

      i18n.extraLocaleSettings = {
        LANGUAGE = "de_DE.UTF-8";
        LC_ADDRESS = _ "de_DE.UTF-8";
        LC_IDENTIFICATION = _ "de_DE.UTF-8";
        LC_MEASUREMENT = _ "de_DE.UTF-8";
        LC_MONETARY = _ "de_DE.UTF-8";
        LC_NAME = _ "de_DE.UTF-8";
        LC_NUMERIC = _ "de_DE.UTF-8";
        LC_PAPER = _ "de_DE.UTF-8";
        LC_TELEPHONE = _ "de_DE.UTF-8";
        LC_TIME = _ "de_DE.UTF-8";
      };

      console = {
        enable = _ true;
        useXkbConfig = _ true;
        font = _ "${pkgs.terminus_font}/share/consolefonts/ter-132n.psf.gz";
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
