# Convert config.monitors into hyprland's format
{ lib, monitors, ... }:
let
  inherit (builtins) map toString;
  displays = builtins.length monitors;
in
{
  home.wayland.windowManager.hyprland.settings = {
    monitor = map (
      m:
      if m.enabled then
        "monitor=${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.x}x${toString m.y},${m.scale} "
      else
        ""
    ) monitors;

    #   # Binding workspaces to monitor
    #   # By default it will always opend on the selected monitor.
    #   # https://wiki.hyprland.org/Configuring/Advanced-config/#binding-workspaces-to-a-monitor
    workspace = lib.concatLists (
      map (
        mon:
        if mon.disable then
          [ ]
        else
          map
            (
              ws:
              "${builtins.toString ws},monitor:${mon.adapter},default:${
                if ws == mon.defaultWorkspace then "true" else "false"
              }"
            )
            (
              if mon.primary && displays == 2 then
                [
                  1
                  2
                  3
                  4
                  5
                ]
              else
                [
                  6
                  7
                  8
                  9
                  10
                ]
            )
      ) monitors
    );
  };
}
