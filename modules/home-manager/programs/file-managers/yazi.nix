{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel isModuleLoadedAndEnabled;

  cfg = config.tensorfiles.hm.programs.file-managers.yazi;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.file-managers.yazi = with types; {
    enable = mkEnableOption ''
      TODO
    '';
    shellWrapperName = lib.mkOption {
      type = types.str;
      default = "y";
      example = "y";
      description = ''
        Name of the shell wrapper to be called.
      '';
    };
    enableBashIntegration = mkOption {
      default = isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash";
      type = types.bool;
      description = ''
        Whether to enable Bash integration.
      '';
    };

    enableZshIntegration = mkOption {
      default = isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh";
      type = types.bool;
      description = ''
        Whether to enable Zsh integration.
      '';
    };

    enableFishIntegration = mkOption {
      default = isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish";
      type = types.bool;
      description = ''
        Whether to enable Fish integration. Note, enabling the direnv module
        will always active its functionality for Fish since the direnv package
        automatically gets loaded in Fish. If this is not the case try adding
        ```nix
          environment.pathsToLink = [ "/share/fish" ];
        ```
        to the system configuration.
      '';
    };

    enableNushellIntegration = mkOption {
      default = isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.nushell";
      type = types.bool;
      description = ''
        Whether to enable Nushell integration.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.yazi = {
        enable = _ true;
        enableBashIntegration = _ cfg.enableBashIntegration;
        enableZshIntegration = _ cfg.enableZshIntegration;
        enableFishIntegration = _ cfg.enableFishIntegration;
        enableNushellIntegration = _ cfg.enableNushellIntegration;
        settings = {
          mgr = {
            sort_by = _ "natural";
            linemode = _ "size";
            show_hidden = _ false;
            show_symlink = _ true;
            ratio = [
              1
              3
              4
            ];
          };
          preview = {
            cache_dir = "${config.xdg.cacheHome}/yazi";
            max_height = 1920;
            max_width = 1080;
          };

          opener = {
            edit = [
              {
                run = ''$EDITOR "$@"'';
                block = true;
              }
            ];
            archive = [
              {
                run = ''unar "$1"'';
                desc = "Extract here";
              }
            ];
            text = [
              {
                run = ''$EDITOR "$@"'';
                block = true;
              }
            ];
            image = [
              {
                run = ''open "$@"'';
                desc = "Open";
              }
              {
                run = ''exiftool "$1"; echo "Press enter to exit"; read'';
                block = true;
                desc = "Show EXIF";
              }
            ];
            video = [
              {run = ''mpv "$@"'';}
              {
                run = ''mediainfo "$1"; echo "Press enter to exit"; read'';
                block = true;
                desc = "Show media info";
              }
            ];
            audio = [
              {run = ''mpv "$@"'';}
              {
                run = ''mediainfo "$1"; echo "Press enter to exit"; read'';
                block = true;
                desc = "Show media info";
              }
            ];
            pdf = [
              {
                run = ''zathura "$@"'';
                for = "linux";
              }
            ];
            fallback = [
              {
                run = ''open "$@"'';
                desc = "Open";
              }
              {
                run = ''open -R "$@"'';
                desc = "Reveal in Finder";
              }
            ];
          };

          open.rules = [
            {
              name = "*/";
              use = "folder";
            }

            {
              mime = "text/*";
              use = "text";
            }
            {
              mime = "image/*";
              use = "image";
            }
            {
              mime = "video/*";
              use = "video";
            }
            {
              mime = "audio/*";
              use = "audio";
            }
            {
              mime = "inode/x-empty";
              use = "text";
            }

            {
              mime = "application/json";
              use = "text";
            }
            {
              mime = "*/javascript";
              use = "text";
            }
            {
              mime = "application/pdf";
              use = ["pdf" "reveal"];
            }

            {
              mime = "application/zip";
              use = "archive";
            }
            {
              mime = "application/gzip";
              use = "archive";
            }
            {
              mime = "application/x-tar";
              use = "archive";
            }
            {
              mime = "application/x-bzip";
              use = "archive";
            }
            {
              mime = "application/x-bzip2";
              use = "archive";
            }
            {
              mime = "application/x-7z-compressed";
              use = "archive";
            }
            {
              mime = "application/x-rar";
              use = "archive";
            }

            {
              mime = "*";
              use = "text";
            }
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      programs = let
        bashIntegration = ''
          function ${cfg.shellWrapperName}() {
            local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
            yazi "$@" --cwd-file="$tmp"
            if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
              builtin cd -- "$cwd"
            fi
            rm -f -- "$tmp"
          }
        '';

        fishIntegration = ''
          set -l tmp (mktemp -t "yazi-cwd.XXXXX")
          command yazi $argv --cwd-file="$tmp"
          if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
          end
          rm -f -- "$tmp"
        '';

        nushellIntegration = ''
          def --env ${cfg.shellWrapperName} [...args] {
            let tmp = (mktemp -t "yazi-cwd.XXXXX")
            yazi ...$args --cwd-file $tmp
            let cwd = (open $tmp)
            if $cwd != "" and $cwd != $env.PWD {
              cd $cwd
            }
            rm -fp $tmp
          }
        '';
      in {
        bash.initExtra = mkIf cfg.enableBashIntegration bashIntegration;

        zsh.initContent = mkIf cfg.enableZshIntegration bashIntegration;

        fish.functions.${cfg.shellWrapperName} =
          mkIf cfg.enableFishIntegration fishIntegration;

        nushell.extraConfig =
          mkIf cfg.enableNushellIntegration nushellIntegration;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
