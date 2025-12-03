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
      # 1. TWS Simulated Trading (HÖCHSTE PRIORITÄT: Matcht den spezifischen Titel)
      # Fenster: "DUK181965 Interactive Brokers (Simulated Trading)"
      # Ziel: tws-simu
      {
        matches = [
          {
            app-id = "jclient-LoginFrame";
            # Regulärer Ausdruck, der "(Simulated Trading)" im Titel sucht.
            title = ".*(Simulated Trading).*";
          }
        ];
        open-on-workspace = "tws-simu";
      }

      # 2. TWS Production Overview (Hohe Priorität: Matcht Titelende mit "Overview")
      # Fenster: "U11213636 Overview"
      # Ziel: tws-prod-overview
      {
        matches = [
          {
            # Der vorhandene Regex war korrekt für Overview am Ende des Titels.
            title = "^(.*Overview)$";
            app-id = "jclient-LoginFrame";
          }
        ];
        open-on-workspace = "tws-prod-overview";
      }

      # 3. TWS Production Main (Niedrigste Priorität/Fallback: Matcht nur die App ID)
      # Fenster: "U11213636 Interactive Brokers"
      # Ziel: tws-prod
      # Diese Regel greift nur, wenn die beiden spezifischeren TWS-Regeln zuvor NICHT gegriffen haben.
      {
        matches = [
          {
            app-id = "jclient-LoginFrame";
          }
        ];
        open-on-workspace = "tws-prod";
      }

      # Regel für Zen-Beta (aus der alten Config übernommen)
      {
        matches = [
          {app-id = "zen-beta";}
        ];
        open-on-workspace = "browser-main";
      }

      # Alle anderen Regeln wurden beibehalten und kommen nach den spezifischen TWS-Regeln:

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
