{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkPywalEnableOption;

  cfg = config.tensorfiles.hm.programs.wlogout;
in {
  options.tensorfiles.hm.programs.wlogout = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };

    pkg = mkOption {
      type = package;
      default = pkgs.dmenu;
      description = ''
        Which package to use for the dmenu binaries. You can provide any
        custom derivation of your choice as long as the main binaries
        reside at

        - `$pkg/bin/dmenu`
        - `$pkg/bin/dmenu_run`
        - etc...
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.wlogout = {
        enable = true;
        layout = [
          {
            "label" = "logout";
            "action" = "loginctl terminate-user $USER";
            "text" = "Logout";
            "keybind" = "l";
          }

          {
            "label" = "reboot";
            "action" = "systemctl reboot";
            "text" = "Reboot";
            "keybind" = "r";
          }

          {
            "label" = "shutdown";
            "action" = "systemctl poweroff";
            "text" = "Power Off";
            "keybind" = "s";
          }
        ];
        style = ''

            * {
              background-image: none;
            }
            window {
              background-color: rgba(12, 12, 12, 1);
            }
            button {
              color: #FFFFFF;
              background-color: #1E1E1E;
              border-radius: 20px;
              background-repeat: no-repeat;
              background-position: center;
              background-size: 50%;
              margin: 10px;
            }

            button:hover {
              background-color: #3b393d;
              outline-style: none;
            }
          #logout {
              background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/logout.png"), url("/usr/local/share/wlogout/icons/logout.png"));
          }

          #shutdown {
              background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/shutdown.png"), url("/usr/local/share/wlogout/icons/shutdown.png"));
          }

          #reboot {
              background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/reboot.png"), url("/usr/local/share/wlogout/icons/reboot.png"));
          }
        '';
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
