{
  lib,
  config,
  pkgs,
  ...
}: let
  apps = import ./applications.nix {inherit pkgs;};
in {
  programs.niri.settings.binds = with config.lib.niri.actions; let
    volume-up = spawn "swayosd-client" ["output-volume" "raise"];
    volume-down = spawn "swayosd-client" ["output-volume" "raise"];
    volume-mute = spawn "swayosd-client" ["output-volume" "mute-toggle"];
  in {
    "xf86audioraisevolume".action = volume-up;
    "xf86audiolowervolume".action = volume-down;
    "xf86audiomute".action = volume-mute;

    "super+q".action = close-window;
    "super+b".action = spawn apps.browser;
    "super+Return".action = spawn apps.terminal;
    "super+Control+Return".action = spawn apps.editor;
    "super+E".action = spawn apps.fileManager;
    "super+n".action = spawn "swaync-client" ["-t" "-sw"];

    "super+f".action = fullscreen-window;
    "super+t".action = toggle-window-floating;

    "super+x".action = spawn launcher;
    # "super+x".action = spawn "wofi" ["-S" "drun" "-x" "10" "-y" "10" "-W" "25%" "-H" "60%"];
    # "super+d".action = spawn "wofi" ["-S" "run"];
    "super+v".action = spawn "${pkgs.bash}/bin/bash" [
      "-c"
      "cliphist list | wofi -dmenu | cliphist decode | wl-copy"
    ];

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

    "super+Shift+Left".action = move-column-left;
    "super+Shift+Right".action = move-column-right;
    "super+Shift+Down".action = move-column-to-workspace-down;
    "super+Shift+Up".action = move-column-to-workspace-up;

    "super+1".action = focus-workspace "browser";
    "super+2".action = focus-workspace "tws";

    # Lock screen
    "super+Escape".action = spawn "wlogout" ["-p" "layer-shell"];
  };
}
