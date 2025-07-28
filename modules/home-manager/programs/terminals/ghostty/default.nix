{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.hm.programs.terminals.ghostty;
  ghostty = inputs.ghostty.packages.${pkgs.system}.default;
in {
  options.tensorfiles.hm.programs.terminals.ghostty = with types; {
    enable = mkEnableOption "Enables Ghostty configuration management through home-manager";

    makeDefault = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to make this terminal default by setting TERMINAL env var";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home = {
        # packages = lib.optional (cfg.package != null) cfg.package;
        sessionVariables.TERMINAL = mkIf cfg.makeDefault "ghostty";
      };
      programs.ghostty = {
        enable = true;
        package = ghostty;
        settings = {
          auto-update = "off";
          background-opacity = 0.8;
          confirm-close-surface = false;
          # Fonts
          font-family = "Atkinson Monolegible";
          # font-family = "Iosevka Nerd Font";
          font-family-bold = "Fira Code";
          font-family-italic = "Maple Mono";
          font-family-bold-italic = "Maple Mono";
          font-size = 18;
          adjust-underline-position = 4;
          # Theme
          # theme = "Dracula";
          # Mouse
          mouse-hide-while-typing = true;
          # Window
          gtk-single-instance = true;
          gtk-tabs-location = "bottom";
          gtk-wide-tabs = false;
          window-padding-y = "2,0";
          window-padding-balance = true;
          window-decoration = "server";

          # Other
          copy-on-select = "clipboard";
          shell-integration-features = "cursor,sudo,no-title";
          keybind = [
            # "clear"
            "ctrl+shift+plus=increase_font_size:1"
            "ctrl+shift+minus=decrease_font_size:1"
            "ctrl+h=goto_split:left"
            "ctrl+j=goto_split:bottom"
            "ctrl+k=goto_split:top"
            "ctrl+l=goto_split:right"
            "ctrl+shift+t=new_tab"
            "ctrl+shift+h=previous_tab"
            "ctrl+shift+l=next_tab"
            "ctrl+shift+comma=move_tab:-1"
            "ctrl+shift+period=move_tab:1"
            "ctrl+shift+c=copy_to_clipboard"
            "ctrl+shift+v=paste_from_clipboard"
            "ctrl+shift+enter=new_split:auto"
            "ctrl+shift+i=inspector:toggle"
            "ctrl+shift+m=toggle_split_zoom"
            "ctrl+shift+r=reload_config"
            "ctrl+shift+s=write_screen_file:open"
            "ctrl+shift+w=close_surface"
          ];
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
