{localFlake}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;
        programs = {
          terminals.ghostty.enable = _ true;
          browsers = {
            vivaldi.enable = _ true;
            chromium.enable = _ true;
            zen-browser.enable = _ true;
          };
          editors.helix.enable = _ true;
        };
      };

      services.rsibreak.enable = _ false;

      home.packages = with pkgs; [
        grim
        imv
        pulseaudio
        cliphist
        ydotool

        # -- FONTS PACKAGES --
        atkinson-hyperlegible # Sans serif for accessibility
        atkinson-monolegible
        corefonts # microsoft fonts
        eb-garamond # free garamond port
        ibm-plex # Striking Fonts from IBM
        iosevka
        jetbrains-mono # monospace
        lmodern # TeX font
        nerd-fonts.iosevka
        noto-fonts-color-emoji # emoji primary
        open-sans # nice sans
        unifont # bitmap font, good fallback
        unifont_upper # upper unicode ranges of unifont
        vollkorn # weighty serif
        noto-fonts # noto fonts: great for fallbacks
        noto-fonts-extra
        noto-fonts-cjk-sans
      ];

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
