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
    volume-up = spawn "swayosd-client" ["output-volume" "raise"];
    volume-down = spawn "swayosd-client" ["output-volume" "raise"];
    volume-mute = spawn "swayosd-client" ["output-volume" "mute-toggle"];
  in {
    # Mod-Shift-/, which is usually the same as Mod-?,
    #, shows a list of important hotkeys.
    "super+Shift+Slash". action = show-hotkey-overlay;

    "super+Tab".action = toggle-overview;

    "super+q".action = close-window;

    "super+b".action = spawn apps.browser;
    "super+Return".action = spawn apps.terminal;
    "super+Control+Return".action = spawn apps.editor;
    "super+E".action = spawn apps.fileManager;
    "super+n".action = spawn "swaync-client" ["-t" "-sw"];

    "super+f".action = fullscreen-window;
    "super+t".action = toggle-window-floating;

    "super+x".action = spawn apps.launcher;
    # "super+x".action = spawn "wofi" ["-S" "drun" "-x" "10" "-y" "10" "-W" "25%" "-H" "60%"];
    # "super+d".action = spawn "wofi" ["-S" "run"];
    # "super+v".action = spawn "${pkgs.bash}/bin/bash" [
    #   "-c"
    #   "cliphist list | wofi -dmenu | cliphist decode | wl-copy"
    # ];

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

    "super+Shift+Left".action = focus-monitor-left;
    "super+Shift+Down".action = focus-monitor-down;
    "super+Shift+Up".action = focus-monitor-up;
    "super+Shift+Right".action = focus-monitor-right;
    # "super+Shift+H".action = focus-monitor-left;
    # "super+Shift+J".action = focus-monitor-down;
    # "super+Shift+K".action = focus-monitor-up;
    # "super+Shift+L".action = focus-monitor-right;

    "super+Shift+Ctrl+Left".action = move-column-to-monitor-left;
    "super+Shift+Ctrl+Down".action = move-column-to-monitor-down;
    "super+Shift+Ctrl+Up".action = move-column-to-monitor-up;
    "super+Shift+Ctrl+Right".action = move-column-to-monitor-right;
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
  };
}
