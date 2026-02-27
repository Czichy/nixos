{localFlake}: {
  config,
  lib,
  pkgs,
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
      # Tools used by the office preview plugin (pandoc is preferred,
      # catdoc / odt2txt serve as lighter fallbacks for legacy formats).
      home.packages = with pkgs; [
        pandoc   # docx, odt, rtf, epub → plain text (primary converter)
        catdoc   # legacy .doc → plain text
        odt2txt  # ODF → plain text
      ];

      programs.yazi = {
        enable = _ true;
        shellWrapperName = cfg.shellWrapperName;
        enableBashIntegration = _ cfg.enableBashIntegration;
        enableZshIntegration = _ cfg.enableZshIntegration;
        enableFishIntegration = _ cfg.enableFishIntegration;
        enableNushellIntegration = _ cfg.enableNushellIntegration;

        # Office document preview plugin (doc/docx/odt/pptx/xlsx/rtf)
        plugins = {
          office = ./yazi-plugins/office.yazi;
        };

        settings = {
          plugin = {
            prepend_previewers = [
              # Word / Rich Text
              { mime = "application/msword"; run = "office"; }
              { mime = "application/rtf"; run = "office"; }
              { mime = "application/vnd.openxmlformats-officedocument.wordprocessingml.*"; run = "office"; }
              # Spreadsheets
              { mime = "application/vnd.ms-excel"; run = "office"; }
              { mime = "application/vnd.openxmlformats-officedocument.spreadsheetml.*"; run = "office"; }
              # Presentations
              { mime = "application/vnd.ms-powerpoint"; run = "office"; }
              { mime = "application/vnd.openxmlformats-officedocument.presentationml.*"; run = "office"; }
              # OpenDocument
              { mime = "application/vnd.oasis.opendocument.*"; run = "office"; }
            ];
          };
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
            office = [
              {
                run = ''libreoffice "$@"'';
                desc = "Open with LibreOffice";
                orphan = true;
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

            # Office documents → open with LibreOffice
            { mime = "application/msword"; use = "office"; }
            { mime = "application/rtf"; use = "office"; }
            { mime = "application/vnd.openxmlformats-officedocument.*"; use = "office"; }
            { mime = "application/vnd.ms-excel"; use = "office"; }
            { mime = "application/vnd.ms-powerpoint"; use = "office"; }
            { mime = "application/vnd.oasis.opendocument.*"; use = "office"; }

            {
              mime = "*";
              use = "text";
            }
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
    # Shell wrapper functions (y/yy) are now provided by upstream
    # programs.yazi via shellWrapperName + enable*Integration options.
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
