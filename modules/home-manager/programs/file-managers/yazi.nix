# --- parts/modules/home-manager/programs/file-managers/yazi.nix
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
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel isModuleLoadedAndEnabled;

  cfg = config.tensorfiles.hm.programs.file-managers.yazi;
  _ = mkOverrideAtHmModuleLevel;
in
{
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
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      xdg.configFile."yazi/yazi.toml" = {
        enable = true;
        text = ''
          [manager]
          layout = [2, 4, 3]
          sort_by = "modified"
          sort_sensitive = true
          sort_reverse = true
          sort_dir_first = true
          show_hidden = false
          show_symlink = true

          [preview]
          tab_size = 2
          max_width = 600
          max_height = 900
          cache_dir = ""

          [opener]
          folder = [
            { exec = 'open -R "$@"', desc = "Reveal in Finder" },
            { exec = '$EDITOR "$@"' },
          ]
          archive = [{ exec = 'unar "$1"', desc = "Extract here" }]
          text = [{ exec = '$EDITOR "$@"', block = true }]
          image = [
            { exec = 'open "$@"', desc = "Open" },
            { exec = '''exiftool "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show EXIF" },
          ]
          video = [
            { exec = 'mpv "$@"' },
            { exec = '''mediainfo "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show media info" },
          ]
          audio = [
            { exec = 'mpv "$@"' },
            { exec = '''mediainfo "$1"; echo "Press enter to exit"; read''', block = true, desc = "Show media info" },
          ]
          fallback = [
            { exec = 'open "$@"', desc = "Open" },
            { exec = 'open -R "$@"', desc = "Reveal in Finder" },
          ]

          [open]
          rules = [
            { name = "*/", use = "folder" },

            { mime = "text/*", use = "text" },
            { mime = "image/*", use = "image" },
            { mime = "video/*", use = "video" },
            { mime = "audio/*", use = "audio" },
            { mime = "inode/x-empty", use = "text" },

            { mime = "application/json", use = "text" },
            { mime = "*/javascript", use = "text" },

            { mime = "application/zip", use = "archive" },
            { mime = "application/gzip", use = "archive" },
            { mime = "application/x-tar", use = "archive" },
            { mime = "application/x-bzip", use = "archive" },
            { mime = "application/x-bzip2", use = "archive" },
            { mime = "application/x-7z-compressed", use = "archive" },
            { mime = "application/x-rar", use = "archive" },

            { mime = "*", use = "fallback" },
          ]

          [tasks]
          micro_workers = 5
          macro_workers = 10
          bizarre_retry = 5

          [log]
          enabled = false
        '';
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
