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
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel;

  cfg = config.tensorfiles.hm.programs.terminals.kitty;
  _ = mkOverrideAtHmModuleLevel;
in
  #nvimScrollbackCheck =
  #  cfg.nvim-scrollback.enable
  #  && (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.editors.neovim");
  {
    options.tensorfiles.hm.programs.terminals.kitty = with types; {
      enable = mkEnableOption ''
        Enables NixOS module that configures/handles terminals.kitty colorscheme generator.
      '';

      #nvim-scrollback = {
      #  enable =
      #    mkEnableOption ''
      #      TODO
      #    ''
      #    // {
      #      default = true;
      #    };
      #};

      pkg = mkOption {
        type = package;
        default = pkgs.kitty;
        description = ''
          TODO
        '';
      };
    };

    config = mkIf cfg.enable (mkMerge [
      # |----------------------------------------------------------------------| #
      {
        programs.kitty = {
          enable = _ true;
          package = _ cfg.pkg;
          font = {
            package = _ pkgs.meslo-lgs-nf;
            name = _ "MesloLGS NF";
          };
          settings = {
            background_opacity = _ "0.8";
            enable_audio_bell = _ false;
            # kitty-scrollback.nvim
            #allow_remote_control = mkIf nvimScrollbackCheck (_ true);
            #shell_integration = mkIf nvimScrollbackCheck (_ "enabled");
          };
          #extraConfig = mkBefore ''
          #  ${
          #    if nvimScrollbackCheck then
          #      ''
          #        listen_on unix:/tmp/kitty
          #        action_alias kitty_scrollback_nvim kitten ${inputs.kitty-scrollback-nvim}/python/kitty_scrollback_nvim.py --no-nvim-args
          #        map ctrl+space kitty_scrollback_nvim
          #        mouse_map kitty_mod+right press ungrabbed combine : mouse_select_command_output : kitty_scrollback_nvim --config ksb_builtin_last_visited_cmd_output
          #      ''
          #    else
          #      ""
          #  }
          #'';
        };

        xdg.configFile."kitty/open-actions.conf" = {
          text = mkBefore ''
            protocol file
            fragment_matches [0-9]+
            action launch --type=overlay $EDITOR +$FRAGMENT $FILE_PATH

            protocol file
            mime text/*
            action launch --type=overlay $EDITOR $FILE_PATH

            protocol file
            mime image/*
            action launch --type=overlay kitty +kitten icat --hold $FILE_PATH

            protocol filelist
            action send_text all ''${FRAGMENT}
          '';
        };
      }
      # |----------------------------------------------------------------------| #
    ]);

    meta.maintainers = with localFlake.lib.maintainers; [czichy];
  }
