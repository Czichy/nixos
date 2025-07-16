{
  config,
  pkgs,
  ...
}: {
  programs.niri.settings = {
    layer-rules = [
      {
        matches = [
          {
            namespace = "wallpaper";
          }
        ];
        place-within-backdrop = true;
      }
    ];
    window-rules = [
      {
        matches = [
          {app-id = "vivaldi";}
        ];
        open-on-workspace = "browser";
      }

      {
        matches = [
          {
            title = "^(.*Interactive Brokers)$";
            app-id = "install4j-jclient-LoginFrame";
          }
        ];
        open-on-workspace = "tws";
        open-on-output = "DP-2";
        # clip-to-geometry = true;
        # open-maximized = true;
      }
      {
        matches = [
          {
            title = "^(.*Overview)$";
            app-id = "jclient-LoginFrame";
          }
        ];
        open-on-output = "DP-3";
        # open-maximized = true;
      }
      # {
      #   matches = [
      #     {
      #       # title = "^(.*Interactive Brokers)$";
      #       app-id = "install4j-jclient-LoginFrame";
      #     }
      #   ];
      #   open-floating = true;
      #   default-floating-position = {
      #     x = 32;
      #     y = 32;
      #     relative-to = "bottom-right";
      #   };
      # }

      # Default rule for all other windows with rounded corners
      {
        matches = [{}]; # Matches all windows not matched by above rules
        clip-to-geometry = true;
      }
      {
        matches = [
          {is-floating = true;}
        ];
        shadow.enable = true;
      }
      {
        matches = [
          {
            is-window-cast-target = true;
          }
        ];
        focus-ring = {
          active.color = "#f38ba8";
          inactive.color = "#7d0d2d";
        };
        border = {
          inactive.color = "#7d0d2d";
        };
        shadow = {
          color = "#7d0d2d70";
        };
        tab-indicator = {
          active.color = "#f38ba8";
          inactive.color = "#7d0d2d";
        };
      }
      {
        matches = [{app-id = "org.telegram.desktop";}];
        block-out-from = "screencast";
      }
      {
        matches = [{app-id = "app.drey.PaperPlane";}];
        block-out-from = "screencast";
      }
      {
        matches = [
          {app-id = "zen";}
          {app-id = "firefox";}
          {app-id = "chromium-browser";}
          {app-id = "xdg-desktop-portal-gtk";}
        ];
        scroll-factor = 0.2;
      }
      {
        matches = [
          {app-id = "zen";}
          {app-id = "firefox";}
          {app-id = "vivaldi";}
          {app-id = "chromium-browser";}
          {app-id = "edge";}
        ];
        open-maximized = true;
      }
      {
        matches = [
          {
            app-id = "firefox";
            title = "Picture-in-Picture";
          }
        ];
        open-floating = true;
        default-floating-position = {
          x = 32;
          y = 32;
          relative-to = "bottom-right";
        };
        default-column-width = {fixed = 480;};
        default-window-height = {fixed = 270;};
      }
      {
        matches = [
          {
            app-id = "zen";
            title = "Picture-in-Picture";
          }
        ];
        open-floating = true;
        default-floating-position = {
          x = 32;
          y = 32;
          relative-to = "bottom-right";
        };
        default-column-width = {fixed = 480;};
        default-window-height = {fixed = 270;};
      }
      {
        matches = [{title = "Picture in picture";}];
        open-floating = true;
        default-floating-position = {
          x = 32;
          y = 32;
          relative-to = "bottom-right";
        };
      }
      {
        matches = [{title = "Discord Popout";}];
        open-floating = true;
        default-floating-position = {
          x = 32;
          y = 32;
          relative-to = "bottom-right";
        };
      }
      {
        matches = [{app-id = "pavucontrol";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "pavucontrol-qt";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "com.saivert.pwvucontrol";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "dialog";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "popup";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "task_dialog";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "gcr-prompter";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "file-roller";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "org.gnome.FileRoller";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "nm-connection-editor";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "blueman-manager";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "xdg-desktop-portal-gtk";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "org.kde.polkit-kde-authentication-agent-1";}];
        open-floating = true;
      }
      {
        matches = [{app-id = "pinentry";}];
        open-floating = true;
      }
      {
        matches = [{title = "Progress";}];
        open-floating = true;
      }
      {
        matches = [{title = "File Operations";}];
        open-floating = true;
      }
      {
        matches = [{title = "Copying";}];
        open-floating = true;
      }
      {
        matches = [{title = "Moving";}];
        open-floating = true;
      }
      {
        matches = [{title = "Properties";}];
        open-floating = true;
      }
      {
        matches = [{title = "Downloads";}];
        open-floating = true;
      }
      {
        matches = [{title = "file progress";}];
        open-floating = true;
      }
      {
        matches = [{title = "Confirm";}];
        open-floating = true;
      }
      {
        matches = [{title = "Authentication Required";}];
        open-floating = true;
      }
      {
        matches = [{title = "Notice";}];
        open-floating = true;
      }
      {
        matches = [{title = "Warning";}];
        open-floating = true;
      }
      {
        matches = [{title = "Error";}];
        open-floating = true;
      }
    ];
  };
}
