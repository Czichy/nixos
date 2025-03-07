{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  # inherit (localFlake.lib) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.programs.zellij;
in {
  options.tensorfiles.hm.programs.zellij = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.zellij = {
        enable = true;
        enableFishIntegration = false;
        settings = {
          theme =
            if pkgs.system == "aarch64-darwin"
            then "dracula"
            else "default";
          # https://github.com/nix-community/home-manager/issues/3854
          themes.dracula = {
            fg = [
              248
              248
              242
            ];
            bg = [
              40
              42
              54
            ];
            black = [
              0
              0
              0
            ];
            red = [
              255
              85
              85
            ];
            green = [
              80
              250
              123
            ];
            yellow = [
              241
              250
              140
            ];
            blue = [
              98
              114
              164
            ];
            magenta = [
              255
              121
              198
            ];
            cyan = [
              139
              233
              253
            ];
            white = [
              255
              255
              255
            ];
            orange = [
              255
              184
              108
            ];
          };
          scroll-buffer-size = 50000;
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
