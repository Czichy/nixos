{
  lib,
  config,
  pkgs,
  ...
}: let
  apps = import ./applications.nix {inherit pkgs config;};
in {
  #, Keys consist of modifiers separated by + signs, followed by an XKB key name
  #, in the end. To find an XKB name for a particular key, you may use a program
  #, like wev.
  #,
  #, "Mod" is a special modifier equal to Super when running on a TTY, and to Alt
  #, when running as a winit window.
  #,
  #, Most actions that you can bind here can also be invoked programmatically with
  #, `niri msg action do-something`.
  programs.niri.settings.binds = with config.lib.niri.actions; let
    volume-up = spawn "swayosd-client" ["--output-volume" "raise"];
    volume-down = spawn "swayosd-client" ["--output-volume" "lower"];
    volume-mute = spawn "swayosd-client" ["--output-volume" "mute-toggle"];
  in {
    # Mod-Shift-/, which is usually the same as Mod-?,
    #, shows a list of important hotkeys.
    "super+F1". action = show-hotkey-overlay;

    "super+Tab".action = toggle-overview;

    "super+Shift+q".action = close-window;

    "super+b".action = spawn apps.browser;
    "super+Return".action = spawn apps.terminal;
    "super+Shift+Return".action = spawn apps.editor;
    "super+E".action = spawn apps.fileManager;
    "super+n".action = spawn "swaync-client" ["-t" "-sw"];

    "super+f".action = fullscreen-window;
    "super+t".action = toggle-window-floating;
    "super+shift+f".action = maximize-column;

    # Expand the focused column to space not taken up by other fully visible columns.
    # Makes the column "fill the rest of the space".
    "super+Ctrl+F".action = expand-column-to-available-width;

    "super+x".action = spawn apps.launcher;

    "control+shift+1".action = spawn "${pkgs.bash}/bin/bash" [
      "-c"
      "${pkgs.grim}/bin/grim -g \"\$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
    ];

    "control+shift+2".action = spawn "${pkgs.bash}/bin/bash" [
      "-c"
      "${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png"
    ];

    "super+Left".action = focus-column-left;
    "super+Right".action = focus-column-right;
    "super+Down".action = focus-workspace-down;
    "super+Up".action = focus-workspace-up;

    "super+Shift+H".action = move-column-left;
    "super+Shift+L".action = move-column-right;
    "super+Shift+J".action = move-column-to-workspace-down;
    "super+Shift+K".action = move-column-to-workspace-up;

    "super+1".action = focus-workspace "browser";
    "super+2".action = focus-workspace "tws";

    # Lock screen
    "super+Escape".action = spawn "wlogout" ["-p" "layer-shell"];

    "alt+Up".action = focus-monitor-next;
    "alt+Down".action = focus-monitor-next;
    "alt+Left".action = focus-monitor-next;
    "alt+Right".action = focus-monitor-next;
    "super+Shift+Up".action = focus-monitor-left;
    "super+Shift+Down".action = focus-monitor-right;

    "alt+Shift+Left".action = move-column-to-monitor-left;
    "alt+Shift+Down".action = move-column-to-monitor-down;
    "alt+Shift+Up".action = move-column-to-monitor-up;
    "alt+Shift+Right".action = move-column-to-monitor-right;
    "super+Shift+Ctrl+H".action = move-column-to-monitor-left;
    "super+Shift+Ctrl+J".action = move-column-to-monitor-down;
    "super+Shift+Ctrl+K".action = move-column-to-monitor-up;
    "super+Shift+Ctrl+L".action = move-column-to-monitor-right;

    "super+WheelScrollDown" = {
      action = focus-workspace-down;
      cooldown-ms = 150;
    };
    "super+WheelScrollUp" = {
      action =
        focus-workspace-up;
      cooldown-ms = 150;
    };
    "super+Ctrl+WheelScrollDown" = {
      action = move-column-to-workspace-down;
      cooldown-ms = 150;
    };

    "super+Ctrl+WheelScrollUp" = {
      action =
        move-column-to-workspace-up;
      cooldown-ms = 150;
    };

    "xf86audioraisevolume".action = volume-up;
    "xf86audiolowervolume".action = volume-down;
    "xf86audiomute".action = volume-mute;

    # Finer width adjustments.
    # This command can also:
    # * set width in pixels: "1000"
    # * adjust width in pixels: "-5" or "+5"
    # * set width as a percentage of screen width: "25%"
    # * adjust width as a percentage of screen width: "-10%" or "+10%"
    # Pixel sizes use logical, or scaled, pixels. I.e. on an output with scale 2.0,
    # set-column-width "100" will make the column occupy 200 physical screen pixels.
    "super+Minus".action.set-column-width = "-10%";
    "super+Plus".action.set-column-width = "+10%";

    # Finer height adjustments when in column with other windows.
    "super+Shift+Minus".action.set-window-height = "-10%";
    "super+Shift+Plus".action.set-window-height = "+10%";

    # Actions to switch layouts.
    # Note: if you uncomment these, make sure you do NOT have
    # a matching layout switch hotkey configured in xkb options above.
    # Having both at once on the same hotkey will break the switching,
    # since it will switch twice upon pressing the hotkey (once by xkb, once by niri).
    # Mod+Space       { switch-layout "next"; }
    # Mod+Shift+Space { switch-layout "prev"; }
  };
}
