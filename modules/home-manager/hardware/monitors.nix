{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled;
  cfg = config.tensorfiles.hm.hardware.monitors;

  hyprlandCheck = isModuleLoadedAndEnabled config "tensorfiles.hm.services.wayland.window-managers.hyprland";
  niriCheck = isModuleLoadedAndEnabled config "tensorfiles.hm.services.wayland.window-managers.niri";
in {
  options.tensorfiles.hm.hardware.monitors = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    monitors = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              example = "DP-1";
            };
            hasBar = mkOption {
              type = types.bool;
              default = false;
            };
            width = mkOption {
              type = types.int;
              example = 1920;
            };
            height = mkOption {
              type = types.int;
              example = 1080;
            };
            refreshRate = mkOption {
              type = types.int;
              default = 60;
            };
            x = mkOption {
              type = types.int;
              default = 0;
            };
            y = mkOption {
              type = types.int;
              default = 0;
            };
            scale = mkOption {
              type = types.str;
              default = "1.0";
              example = "1.0";
            };
            enabled = mkOption {
              type = types.bool;
              default = true;
            };

            transform = mkOption {
              type = types.int;
              default = 0;
            };

            primary = mkOption {
              type = types.bool;
              default = false;
            };
            defaultWorkspace = mkOption {
              type = types.nullOr types.int;
              default = null;
            };
          };
        }
      );
      default = [];
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      assertions = [
        {
          assertion =
            ((lib.length cfg.monitors) != 0) -> ((lib.length (lib.filter (m: m.primary) cfg.monitors)) == 1);
          message = "Exactly one monitor must be set to primary.";
        }
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf hyprlandCheck {
      wayland.windowManager.hyprland.settings = {
        monitor =
          map (
            m:
              if m.enabled
              then "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.x}x${toString m.y},${m.scale} ,transform, ${toString m.transform}"
              else ""
          )
          cfg.monitors;

        #   # Binding workspaces to monitor
        #   # By default it will always opend on the selected monitor.
        #   # https://wiki.hyprland.org/Configuring/Advanced-config/#binding-workspaces-to-a-monitor
        workspace = lib.concatLists (
          map (
            m:
              if m.enabled
              then
                map
                (
                  ws: "${builtins.toString ws},monitor:${m.name},default:${
                    if ws == m.defaultWorkspace
                    then "true"
                    else "false"
                  }"
                )
                (
                  if m.primary && builtins.length cfg.monitors == 2
                  then [
                    1
                    2
                    3
                    4
                    5
                  ]
                  else [
                    6
                    7
                    8
                    9
                    10
                  ]
                )
              else []
          )
          cfg.monitors
        );
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf niriCheck {
      programs.niri.outputs = {
        monitor =
          map (
            m:
              if m.enabled
              then "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.x}x${toString m.y},${m.scale} ,transform, ${toString m.transform}"
              else ""
          )
          cfg.monitors;

        #   # Binding workspaces to monitor
        #   # By default it will always opend on the selected monitor.
        #   # https://wiki.hyprland.org/Configuring/Advanced-config/#binding-workspaces-to-a-monitor
        workspace = lib.concatLists (
          map (
            m:
              if m.enabled
              then
                map
                (
                  ws: "${builtins.toString ws},monitor:${m.name},default:${
                    if ws == m.defaultWorkspace
                    then "true"
                    else "false"
                  }"
                )
                (
                  if m.primary && builtins.length cfg.monitors == 2
                  then [
                    1
                    2
                    3
                    4
                    5
                  ]
                  else [
                    6
                    7
                    8
                    9
                    10
                  ]
                )
              else []
          )
          cfg.monitors
        );
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
