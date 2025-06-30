{localFlake}: {
  pkgs,
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmProfileLevel;

  cfg = config.tensorfiles.hm.profiles.graphical-niri;
  _ = mkOverrideAtHmProfileLevel;
in {
  options.tensorfiles.hm.profiles.graphical-niri = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  #imports = with inputs; [stylix.nixosModules.stylix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    #(import ./rc2nix.nix)
    # |----------------------------------------------------------------------| #
    {
      tensorfiles.hm = {
        profiles.headless.enable = _ true;
        # hardware.nixGL.enable = _ true;
        services.wayland.window-managers.niri.enable = _ true;
        services.swaync.enable = _ true;
        programs = {
          terminals.foot.enable = _ true;
          terminals.ghostty.enable = _ true;
          browsers = {
            vivaldi.enable = _ true;
            # zen-browser.enable = _ true;
          };
          editors.helix.enable = _ true;
          wlogout.enable = _ true;
          walker.enable = _ true;
        };
      };

      # services.flameshot = {
      #   enable = _ true;
      #   settings = {
      #     General.showStartupLaunchMessage = _ false;
      #   };
      # };

      services.rsibreak.enable = _ false;

      home.sessionVariables = {
        # Default programs
        BROWSER = _ "vivaldi";
        EXPLORER = _ "yazi";
        # TERMINAL = _ "foot";
        EDITOR = _ "hx";
        LAUNCHER = _ "walker";

        # Wayland
        MOZ_ENABLE_WAYLAND = 1;
        QT_QPA_PLATFORM = "wayland";
        LIBSEAT_BACKEND = "logind";
      };
      home.packages = with pkgs; [
        grim
        imv
        pulseaudio
        slurp
        waypipe
        wf-recorder
        wl-clipboard # Command-line copy/paste utilities for Wayland
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
        swayosd
      ];

      fonts.fontconfig.enable = _ true;

      services.network-manager-applet.enable = _ true;

      programs = {
        fish.loginShellInit = ''
          # if status is-login; and test -z "$DISPLAY"; and test (tty) = "/dev/tty1"
          #   set _JAVA_AWT_WM_NONEREPARENTING 1
          #   niri-session
          # end
          if test (tty) = "/dev/tty1"
            set _JAVA_AWT_WM_NONEREPARENTING 1
            pgrep niri >/dev/null || exec niri-session
          end
        '';
        #  zsh.loginExtra = ''
        #    if [ "$(tty)" = "/dev/tty1" ]; then
        #      exec Hyprland &> /dev/null
        #    fi
        #  '';
        #  zsh.profileExtra = ''
        #    if [ "$(tty)" = "/dev/tty1" ]; then
        #      exec Hyprland &> /dev/null
        #    fi
        #  '';
      };
      ## WARN: Check if this breaks when the hyprland module is not in imports.
      ## Enter Hyprland when logging into tty1 if Hyprland is enabled.
      xdg.configFile."nushell/login.nu".text = ''
        if (tty) == "/dev/tty1" {
          exec niri-session | ignore
        }
      '';
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
