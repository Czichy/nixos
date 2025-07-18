{
  lib,
  pkgs,
  ...
}: {
  programs.niri.settings.spawn-at-startup = [
    {command = ["systemctl" "--user" "start" "hyprpolkitagent"];}
    {command = ["arrpc"];}
    {command = ["xwayland-satellite"];}
    {command = ["qs"];}
    {command = ["hyprlock"];}
    {command = ["swww-daemon"];}
    {command = ["wl-paste" "--watch" "cliphist" "store"];}
    {command = ["wl-paste" "--type text" "--watch" "cliphist" "store"];}
    {command = ["${pkgs.swaynotificationcenter}/bin/swaync"];}
    {command = ["swayosd --max-volume 150"];}
    {command = ["xprop -root -f _XWAYLAND_GLOBAL_OUTPUT_SCALE 32c -set _XWAYLAND_GLOBAL_OUTPUT_SCALE 1"];}
    {command = ["vivaldi"];}
  ];
}
