{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  inherit (lib) mkOption types mkIf;

  cfg = config.tensorfiles.hm.desktop;
in {
  options.tensorfiles.hm.desktop = {
    isWayland = mkOption {
      type = types.bool;
      # TODO: there must be a better way to do this
      default = with cfg.window-managers; (niri.enable || hyprland.enable);
      defaultText = "This will default to true if a Wayland compositor has been enabled";
      description = ''
        Whether to enable Wayland exclusive modules, this contains a wariety
        of packages, modules, overlays, XDG portals and so on.

        Generally includes:
          - Wayland nixpkgs overlay
          - Wayland only services
          - Wayland only programs
          - Wayland compatible versions of packages as opposed
          to the defaults
      '';
    };
  };

  config = mkIf cfg.isWayland (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs; [
        grimblast
        slurp
        swaybg
        swayosd
        waypipe
        wdisplays
        wf-recorder
        wl-clipboard
      ];
    }
    # |----------------------------------------------------------------------| #
    {
      home.sessionVariables = {
        GDK_BACKEND = "wayland,x11";
        XDG_SESSION_TYPE = "wayland";
        SDL_VIDEODRIVER = "wayland";
        QT_QPA_PLATFORM = "wayland;xcb";
        LIBSEAT_BACKEND = "logind";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        MOZ_ENABLE_WAYLAND = "1";
        _JAVA_AWT_WM_NONREPARENTING = "1";
        NIXOS_OZONE_WL = "1";
        GTK_USE_PORTAL = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        # ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
    }
    # |----------------------------------------------------------------------| #
  ]);
}
