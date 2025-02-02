{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkAgenixEnableOption;
  inherit (config.home.sessionVariables) TERMINAL BROWSER EXPLORER; # EDITOR

  ibkr = {
    user = config.age.secrets."${config.tensorfiles.hm.programs.ib-tws.userSecretsPath}".path;
    password = config.age.secrets."${config.tensorfiles.hm.programs.ib-tws.passwordSecretsPath}".path;
  };

  cfg = config.tensorfiles.hm.services.wayland.window-managers.hyprland;
  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.hm.services.wayland.window-managers.hyprland = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the hyprland window manager.
    '';

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home = {
        packages = with pkgs; [
          hyprland-qtutils
          hyprpicker
          grimblast
          swaybg
          slurp
          swappy
          # swayidle
          jaq
          xorg.xprop
          wdisplays
        ];
      };

      # services.flameshot = {
      #   enable = _ true;
      #   settings = {
      #     General.showStartupLaunchMessage = _ false;
      #   };
      # };

      # programs.waybar.package = pkgs.waybar.overrideAttrs (oa: {
      #   mesonFlags = (oa.mesonFlags or []) ++ ["-Dexperimental=true"];
      # });

      wayland.windowManager.hyprland = {
        enable = true;
        package = pkgs.hyprland.override {wrapRuntimeDeps = false;};

        settings = mkMerge [
          {
            env = [
              "NIXOS_OZONE_WL,1"
              "MOZ_ENABLE_WAYLAND,1"
              "MOZ_WEBRENDER,1"
              "_JAVA_AWT_WM_NONREPARENTING,1"
              "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
              "QT_QPA_PLATFORM,wayland"
              "SDL_VIDEODRIVER,wayland"
              "GDK_BACKEND,wayland"
              # toolkit-specific scale
              "GDK_SCALE,2"
              "QT_SCALE_FACTOR,2"
              "XCURSOR_SIZE,32"
            ];
            exec-once = [
              # Startup
              # "swaybg -i ${wallpaper} --mode fill"
              "${pkgs.swaynotificationcenter}/bin/swaync"
              # "[workspace 7] firefox -P 'tradingview1' --class=tradingview"
              "[workspace 6] ${BROWSER}"
              "wl-paste --type text --watch cliphist store #Stores only text data"
              "wl-paste --type image --watch cliphist store #Stores only image data"
              "[workspace special:pass silent] bitwarden"
              # "[workspace special:pass silent] keepassxc"
              "swayosd --max-volume 150"
              "xprop -root -f _XWAYLAND_GLOBAL_OUTPUT_SCALE 32c -set _XWAYLAND_GLOBAL_OUTPUT_SCALE 1"

              (mkIf agenixCheck "ib-tws-native -u $(< ${ibkr.user}) -p $(< ${ibkr.password})")
              (mkIf (!agenixCheck) "ib-tws-native")
            ];

            bind =
              [
                "SUPER + CTRL + SHIFT,q,exit"
                # Applications
                # Program bindings
                "SUPER,Return,exec,${TERMINAL}"
                "SUPER, e, exec, ${EXPLORER}" # open file manager
                "SUPER,w,exec,makoctl dismiss"
                # SUPER,v,exec,${TERMINAL} $SHELL -ic ${EDITOR}
                "SUPER,b,exec,[workspace 6] ${BROWSER}"
                "SUPER,t,exec,[workspace 7] ${BROWSER} -P tradingview1 --class=tradingview"

                "SUPER,x,exec,wofi -S drun -x 10 -y 10 -W 25% -H 60%"
                "SUPER,d,exec,wofi -S run"
                "SUPER,v,exec, cliphist list | wofi -dmenu | cliphist decode | wl-copy"
                #",Scroll_Lock,exec,pass-wofi # fn+k"
                #",XF86Calculator,exec,pass-wofi # fn+f12"

                # Toggle waybar"
                ",XF86Tools,exec,pkill -USR1 waybar # profile button"

                # Lock screen
                "SUPER, Escape, exec, wlogout -p layer-shell"

                # Sway Nc
                "SUPER,N,exec,swaync-client -t -sw"

                # Screenshots
                ",Print,exec,grimblast --notify copy output"
                "SHIFT,Print,exec,grimblast --notify copy active"
                "CTRL,Print,exec,grimblast save area - | ${lib.getExe pkgs.swappy} -f -"
                #"CONTROL,Print,exec,grimblast --notify copy screen"
                "SUPER,Print,exec,grimblast --notify copy window"
                "ALT,Print,exec,grimblast --notify copy area"

                # Per-window actions
                "SUPER + SHIFT,q,killactive,"
                "SUPER,f,fullscreen,1"
                "SUPER + SHIFT,space,togglefloating"
                "SUPERSHIFT,f,fullscreen,0"
                "SUPER,minus,splitratio,-0.25"
                "SUPERSHIFT,minus,splitratio,-0.3333333"

                "SUPER,plus,splitratio,0.25"
                "SUPER + SHIFT,plus,splitratio,0.3333333"

                "SUPER,g,togglegroup"
                "SUPER,apostrophe,changegroupactive,f"
                "SUPER + SHIFT,apostrophe,changegroupactive,b"

                "SUPER,tab,cyclenext,"
                "ALT,tab,cyclenext,"
                "SUPER + SHIFT,tab,cyclenext,prev"
                "ALT + SHIFT,tab,cyclenext,prev"

                "SUPER,left,movefocus,l"
                "SUPER,right,movefocus,r"
                "SUPER,up,movefocus,u"
                "SUPER,down,movefocus,d"

                "SUPER + SHIFT,left,movewindow,l"
                "SUPER + SHIFT,right,movewindow,r"
                "SUPER + SHIFT,up,movewindow,u"
                "SUPER + SHIFT,down,movewindow,d"

                "SUPER,comma,workspace,-1"
                "SUPER,period,workspace,+1"
                "SUPER + SHIFT,comma,movetoworkspacesilent,-1"
                "SUPER + SHIFT,period,movetoworkspacesilent,+1"

                ", XF86AudioMute, exec, swayosd --output-volume mute-toggle"
                ", XF86AudioMicMute, exec, swayosd --input-volume mute-toggle"

                # Special Workspaces
                "SUPER,u,togglespecialworkspace"
                "SUPER + SHIFT,u,movetoworkspace,special"
                "SUPER,p,togglespecialworkspace, pass"
                "SUPER + SHIFT,p,movetoworkspace,special:pass"
              ]
              ++ flip concatMap (map toString (lib.lists.range 1 9)) (x: [
                "SUPER,${x},workspace,${x}"
                "SUPER + SHIFT,${x},movetoworkspacesilent,${x}"
              ]);

            bindle = [
              ", XF86AudioRaiseVolume, exec, swayosd --output-volume raise"
              ", XF86AudioLowerVolume, exec, swayosd --output-volume lower"
              "SHIFT, XF86AudioRaiseVolume, exec, swayosd --input-volume raise"
              "SHIFT, XF86AudioLowerVolume, exec, swayosd --input-volume lower"
            ];

            bindm = [
              # mouse movements
              "SUPER, mouse:272, movewindow"
              "SUPER, mouse:273, resizewindow"
              "SUPER ALT, mouse:272, resizewindow"
            ];
            #window rules
            windowrulev2 = [
              "workspace 2,title:^(.*Interactive Brokers)$"
              "workspace 3,class:obsidian"
              "workspace 8,title:^(.*Seeking Edge)$"
            ];

            animations = {
              enabled = true;
              animation = [
                "windows, 1, 4, default, slide"
                "windowsOut, 1, 4, default, slide"
                "windowsMove, 1, 4, default"
                "border, 1, 2, default"
                "fade, 1, 4, default"
                "fadeDim, 1, 4, default"
                "workspaces, 1, 4, default"
              ];
            };

            decoration = {
              active_opacity = 1.0;
              inactive_opacity = 1.0;
              fullscreen_opacity = 1.0;
              rounding = 5;
              shadow = {
                range = 12;
                offset = "0 3";
                color = "0x44000000";
                color_inactive = "0x66000000";
              };
            };

            input = {
              kb_layout = "de,noted";
              kb_variant = "nodeadkeys,noted";
              kb_options = "grp:sclk_toggle";
              follow_mouse = 2;
              numlock_by_default = true;
              repeat_rate = 100;
              repeat_delay = 150;
              # Only change focus on mouse click
              float_switch_override_focus = 0;
              # accel_profile = "flat";

              touchpad = {
                #   natural_scroll = "no";
                disable_while_typing = true;
                #   clickfinger_behavior = true;
                #   scroll_factor = 0.7;
              };
            };

            general = {
              "col.active_border" = "0xFFa1efe4";
              gaps_in = 3;
              gaps_out = 0;
              border_size = 2;
              # allow_tearing = true;
            };

            debug.disable_logs = false;

            dwindle = {
              split_width_multiplier = 1.35;
            };

            misc = {
              # vfr = 1;
              # vrr = 1;
              disable_hyprland_logo = true;
              # mouse_move_focuses_monitor = false;
            };
          }
        ];

        extraConfig = ''
            env = _JAVA_AWT_WM_NONREPARENTING,1
            env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1

            binds {
            focus_preferred_method = 1
          }
        '';
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
