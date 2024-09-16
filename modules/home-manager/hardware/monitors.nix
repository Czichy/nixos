# --- parts/modules/home-manager/hardware/nixGL.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{ localFlake }:
{ config, lib, ... }:
with builtins;
with lib;
let
  inherit (localFlake.lib) isModuleLoadedAndEnabled;
  cfg = config.tensorfiles.hm.hardware.monitors;

  hyprlandCheck = isModuleLoadedAndEnabled config "tensorfiles.hm.services.wayland.window-managers.hyprland";
in
{
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
      default = [ ];
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
        monitor = map (
          m:
          if m.enabled then
            "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate},${toString m.x}x${toString m.y},${m.scale} "
          else
            ""
        ) cfg.monitors;

        #   # Binding workspaces to monitor
        #   # By default it will always opend on the selected monitor.
        #   # https://wiki.hyprland.org/Configuring/Advanced-config/#binding-workspaces-to-a-monitor
        workspace = lib.concatLists (
          map (
            m:
            if m.enabled then
              map
                (
                  ws:
                  "${builtins.toString ws},monitor:${m.name},default:${
                    if ws == m.defaultWorkspace then "true" else "false"
                  }"
                )
                (
                  if m.primary && builtins.length cfg.monitors == 2 then
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
            else
              [ ]
          ) cfg.monitors
        );
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
