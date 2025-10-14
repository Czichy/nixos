{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  # inherit (localFlake.lib) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.programs.fastfetch;
in {
  options.tensorfiles.hm.programs.fastfetch = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = [pkgs.fastfetch];

      xdg.configFile."fastfetch/config.jsonc".text =
        # jsonc
        ''
          {
            "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
            "modules": [
              "title",
              "separator",
              {
                "type": "os",
                "format": "{3} {12}"
              },
              {
                "type": "host",
                "format": "{/2}{-}{/}{2}{?3} {3}{?}"
              },
              "kernel",
              "uptime",
              "packages",
              "shell",
              {
                "type": "display",
                "compactType": "original",
                "key": "Resolution"
              },
              "de",
              "wm",
              "wmtheme",
              "icons",
              "cursor",
              "terminal",
              {
                "type": "terminalfont",
                "format": "{/2}{-}{/}{2}{?3} {3}{?}"
              },
              "cpu",
              {
                "type": "gpu",
                "key": "GPU"
              },
              {
                "type": "memory",
                "format": "{/1}{-}{/}{/2}{-}{/}{} / {}"
              },
              "disk",
            ]
          }
        '';
    }
    # |----------------------------------------------------------------------| #
  ]);
}
