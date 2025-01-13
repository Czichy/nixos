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
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.yazi = {
        enable = _ true;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        enableZshIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh");
        enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
        enableNushellIntegration = _ (
          isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.nushell"
        );
        settings = {
          manager = {
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
            folder = [
              {
                run = ''open -R "$@"'';
                desc = "Reveal in Finder";
              }
              {run = ''$EDITOR "$@"'';}
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
              use = "fallback";
            }
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
    # {
    #   xdg.configFile."yazi/yazi.toml" = {
    #     enable = true;
    #     text = ''
    #       [manager]
    #       layout = [2, 3, 3]
    #       sort_by = "modified"
    #       sort_sensitive = true
    #       sort_reverse = true
    #       sort_dir_first = true
    #       show_hidden = false
    #       show_symlink = true

    #       [preview]
    #       tab_size = 2
    #       max_width = 1024
    #       max_height = 900
    #       cache_dir = ""

    #       [opener]
    #       folder = [
    #         { exec = 'open -R "$@"', desc = "Reveal in Finder" },
    #         { exec = '$EDITOR "$@"' },
    #       ]
    #       archive = [{ exec = 'unar "$1"', desc = "Extract here" }]
    #       text = [{ exec = '$EDITOR "$@"', block = true }]
    #       image = [
    #         { exec = 'open "$@"', desc = "Open" },
    #         { exec = '''exiftool "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show EXIF" },
    #       ]
    #       video = [
    #         { exec = 'mpv "$@"' },
    #         { exec = '''mediainfo "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show media info" },
    #       ]
    #       audio = [
    #         { exec = 'mpv "$@"' },
    #         { exec = '''mediainfo "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show media info" },
    #       ]
    #       fallback = [
    #         { exec = 'open "$@"', desc = "Open" },
    #         { exec = 'open -R "$@"', desc = "Reveal in Finder" },
    #       ]

    #       [open]
    #       rules = [
    #         { name = "*/", use = "folder" },

    #         { mime = "text/*", use = "text" },
    #         { mime = "image/*", use = "image" },
    #         { mime = "video/*", use = "video" },
    #         { mime = "audio/*", use = "audio" },
    #         { mime = "inode/x-empty", use = "text" },

    #         { mime = "application/json", use = "text" },
    #         { mime = "*/javascript", use = "text" },

    #         { mime = "application/zip", use = "archive" },
    #         { mime = "application/gzip", use = "archive" },
    #         { mime = "application/x-tar", use = "archive" },
    #         { mime = "application/x-bzip", use = "archive" },
    #         { mime = "application/x-bzip2", use = "archive" },
    #         { mime = "application/x-7z-compressed", use = "archive" },
    #         { mime = "application/x-rar", use = "archive" },

    #         { mime = "*", use = "fallback" },
    #       ]

    #       [tasks]
    #       micro_workers = 5
    #       macro_workers = 10
    #       bizarre_retry = 5

    #       [log]
    #       enabled = false
    #     '';
    #   };
    # }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
