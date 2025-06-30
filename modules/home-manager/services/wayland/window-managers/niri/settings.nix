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

      gaps = 6;
      center-focused-column = "never";
      preset-column-widths = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];
      default-column-width = {proportion = 0.5;};

      struts = {
        left = 20;
        right = 20;
        top = 20;
        bottom = 20;
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
      CLUTTER_BACKEND = "wayland";
      ELECTRON_ENABLE_HARDWARE_ACCELERATION = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      GDK_BACKEND = "wayland,x11";
      MOZ_ENABLE_WAYLAND = "1";
      MOZ_WEBRENDER = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "niri";
      # DISPLAY = ":0";
    };
  };
}
# {
#   config,
#   pkgs,
#   ...
# }: let
#   # pointer = config.home.pointerCursor;
#   makeCommand = command: {
#     command = [command];
#   };
# in {
#   programs.niri = {
#     settings = {
#       environment = {
#         CLUTTER_BACKEND = "wayland";
#         DISPLAY = null;
#         GDK_BACKEND = "wayland,x11";
#         MOZ_ENABLE_WAYLAND = "1";
#         NIXOS_OZONE_WL = "1";
#         QT_QPA_PLATFORM = "wayland;xcb";
#         QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
#         SDL_VIDEODRIVER = "wayland";
#       };
#       spawn-at-startup = [
#         (makeCommand "hyprlock")
#         (makeCommand "swww-daemon")
#         (makeCommand "swayosd-server")
#         {command = ["wl-paste" "--watch" "cliphist" "store"];}
#         {command = ["wl-paste" "--type text" "--watch" "cliphist" "store"];}
#         {command = ["${pkgs.swaynotificationcenter}/bin/swaync"];}
#         {command = ["swayosd --max-volume 150"];}
#         {command = ["xprop -root -f _XWAYLAND_GLOBAL_OUTPUT_SCALE 32c -set _XWAYLAND_GLOBAL_OUTPUT_SCALE 1"];}
#       ];
#       input = {
#         keyboard.xkb.layout = "de,noted";
#         # touchpad = {
#         #   click-method = "button-areas";
#         #   dwt = true;
#         #   dwtp = true;
#         #   natural-scroll = true;
#         #   scroll-method = "two-finger";
#         #   tap = true;
#         #   tap-button-map = "left-right-middle";
#         #   middle-emulation = true;
#         #   accel-profile = "adaptive";
#         # };
#         focus-follows-mouse.enable = true;
#         warp-mouse-to-focus.enable = true;
#         workspace-auto-back-and-forth = true;
#       };
#       screenshot-path = "~/Screenshots/Screenshot-from-%Y-%m-%d-%H-%M-%S.png";
#       outputs = {
#         "DP-2" = {
#           focus-at-startup = true;
#           mode = {
#             width = 3840;
#             height = 2160;
#             refresh = null;
#           };
#           scale = 1.0;
#           position = {
#             x = 0;
#             y = 0;
#           };
#         };
#         "DP-3" = {
#           mode = {
#             width = 3840;
#             height = 2160;
#             refresh = null;
#           };
#           scale = 1.0;
#           transform.rotation = 270;
#           position = {
#             x = 3840;
#             y = -867;
#           };
#         };
#       };
#       overview = {
#         # workspace-shadow = "off";
#         backdrop-color = "transparent";
#       };
#       gestures = {hot-corners.enable = true;};
#       cursor = {
#         size = 20;
#         # theme = "${pointer.name}";
#       };
#       layout = {
#         focus-ring.enable = false;
#         border = {
#           enable = true;
#           width = 1;
#           active.color = "#7fb4ca";
#           inactive.color = "#090e13";
#         };
#         shadow = {
#           enable = true;
#         };
#         preset-column-widths = [
#           {proportion = 0.25;}
#           {proportion = 0.5;}
#           {proportion = 0.75;}
#           {proportion = 1.0;}
#         ];
#         default-column-width = {proportion = 0.5;};
#         gaps = 6;
#         struts = {
#           left = 0;
#           right = 0;
#           top = 0;
#           bottom = 0;
#         };
#         tab-indicator = {
#           hide-when-single-tab = true;
#           place-within-column = true;
#           position = "left";
#           corner-radius = 20.0;
#           gap = -12.0;
#           gaps-between-tabs = 10.0;
#           width = 4.0;
#           length.total-proportion = 0.1;
#         };
#       };
#       # animations.shaders.window-resize.custom_shader = ''
#       #   vec4 resize_color(vec3 coords_curr_geo, vec3 size_curr_geo) {
#       #     vec3 coords_next_geo = niri_curr_geo_to_next_geo * coords_curr_geo;
#       #     vec3 coords_stretch = niri_geo_to_tex_next * coords_curr_geo;
#       #     vec3 coords_crop = niri_geo_to_tex_next * coords_next_geo;
#       #     // We can crop if the current window size is smaller than the next window
#       #     // size. One way to tell is by comparing to 1.0 the X and Y scaling
#       #     // coefficients in the current-to-next transformation matrix.
#       #     bool can_crop_by_x = niri_curr_geo_to_next_geo[0][0] <= 1.0;
#       #     bool can_crop_by_y = niri_curr_geo_to_next_geo[1][1] <= 1.0;
#       #     vec3 coords = coords_stretch;
#       #     if (can_crop_by_x)
#       #         coords.x = coords_crop.x;
#       #     if (can_crop_by_y)
#       #         coords.y = coords_crop.y;
#       #     vec4 color = texture2D(niri_tex_next, coords.st);
#       #     // However, when we crop, we also want to crop out anything outside the
#       #     // current geometry. This is because the area of the shader is unspecified
#       #     // and usually bigger than the current geometry, so if we don't fill pixels
#       #     // outside with transparency, the texture will leak out.
#       #     //
#       #     // When stretching, this is not an issue because the area outside will
#       #     // correspond to client-side decoration shadows, which are already supposed
#       #     // to be outside.
#       #     if (can_crop_by_x && (coords_curr_geo.x < 0.0 || 1.0 < coords_curr_geo.x))
#       #         color = vec4(0.0);
#       #     if (can_crop_by_y && (coords_curr_geo.y < 0.0 || 1.0 < coords_curr_geo.y))
#       #         color = vec4(0.0);
#       #     return color;
#       #   }
#       # '';
#       prefer-no-csd = true;
#       hotkey-overlay.skip-at-startup = true;
#     };
#   };
# }

