{
  config,
  pkgs,
  ...
}: {
  programs.niri.settings = {
    workspaces = {
      "browser" = {
        open-on-output = "DP-3";
      };
      "tws" = {
        open-on-output = "DP-2";
      };
    };

    prefer-no-csd = true;

    hotkey-overlay = {
      skip-at-startup = true;
    };

    layout = {
      focus-ring = {
        enable = true;
        width = 3;
        active = {
          color = "#c488ec";
        };
        inactive = {
          color = "#505050";
        };
      };

      gaps = 12;
      center-focused-column = "never";
      always-center-single-column = true;
      preset-column-widths = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];
      default-column-width = {proportion = 0.5;};

      struts = {
        left = -6;
        right = -6;
        top = -6;
        bottom = -6;
      };
    };

    input = {
      keyboard = {
        repeat-delay = 150;
        repeat-rate = 100;
        track-layout = "global";
        xkb = {
          layout = "de,noted";
          options = "grp:sclk_toggle";
        };
      };
      mouse = {
        # // natural-scroll
        accel-speed = 0.2;
        # // accel-profile "flat"
        scroll-factor = 3.0;
        # scroll-factor vertical=1.0 horizontal=-2.0
        # // scroll-method "no-scroll"
        # // scroll-button 273
        # // scroll-button-lock
        # // left-handed
        # // middle-emulation
      };

      # numlock = true;
      focus-follows-mouse.enable = true;
      warp-mouse-to-focus.enable = false;
    };

    outputs = {
      "DP-2" = {
        focus-at-startup = true;
        mode = {
          width = 3840;
          height = 2160;
          refresh = null;
        };
        scale = 1.0;
        position = {
          x = 0;
          y = 0;
        };
      };
      "DP-3" = {
        mode = {
          width = 3840;
          height = 2160;
          refresh = null;
        };
        scale = 1.0;
        transform.rotation = 270;
        position = {
          x = 3840;
          y = -867;
        };
      };
    };

    cursor = {
      size = 20;
      theme = "Adwaita";
    };

    environment = {
      # CLUTTER_BACKEND = "wayland";
      # ELECTRON_ENABLE_HARDWARE_ACCELERATION = "1";
      # ELECTRON_OZONE_PLATFORM_HINT = "auto";
      # GDK_BACKEND = "wayland";
      # _JAVA_AWT_WM_NONEREPARENTING = "1";
      # MOZ_ENABLE_WAYLAND = "1";
      # MOZ_WEBRENDER = "1";
      # NIXOS_OZONE_WL = "1";
      # QT_QPA_PLATFORM = "wayland";
      # QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      DISPLAY = ":0";
    };
  };
}
