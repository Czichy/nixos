{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.hm.programs.terminals.foot;
in
  #nvimScrollbackCheck =
  #  cfg.nvim-scrollback.enable
  #  && (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.editors.neovim");
  {
    options.tensorfiles.hm.programs.terminals.foot = with types; {
      enable = mkEnableOption ''
        Enables NixOS module that configures/handles terminals.foot colorscheme generator.
      '';

      makeDefault = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to make this terminal default by setting TERMINAL env var";
      };

      pkg = mkOption {
        type = package;
        default = pkgs.foot;
        description = ''
          TODO
        '';
      };
    };

    config = mkIf cfg.enable (mkMerge [
      # |----------------------------------------------------------------------| #
      {
        home = {
          # packages = lib.optional (cfg.package != null) cfg.package;
          sessionVariables.TERMINAL = mkIf cfg.makeDefault "foot";
        };
        programs.foot = {
          enable = true;

          settings = {
            main = {
              font = "Atkinson Monolegible:size=14";
              # font = "Iosevka Nerd Font:size=12";
              # font = "${config.fontProfiles.monospace.family}:size=${toString default.terminal.size}";
              box-drawings-uses-font-glyphs = "yes";
              dpi-aware = "yes";
              pad = "0x0center";
              # notify = "notify-send -a \${app-id} -i \${app-id} \${title} \${body}";
              selection-target = "primary";
            };

            scrollback = {
              lines = 1000000;
              multiplier = 3;
            };

            url = {
              launch = "xdg-open \${url}";
              label-letters = "sadfjklewcmpgh";
              osc8-underline = "url-mode";
              regex = "(((https?://|mailto:|ftp://|file:|ssh:|ssh://|git://|tel:|magnet:|ipfs://|ipns://|gemini://|gopher://|news:)|www\.)([0-9a-zA-Z:/?#@!$&*+,;=.~_%^\-]+|\([]\[\"0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\)|\[[\(\)\"0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\]|\"[]\[\(\)0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\"|'[]\[\(\)0-9a-zA-Z:/?#@!$&*+,;=.~_%^\-]*')+([0-9a-zA-Z/#@$&*+=~_%^\-]|\([]\[\"0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\)|\[[\(\)\"0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\]|\"[]\[\(\)0-9a-zA-Z:/?#@!$&'*+,;=.~_%^\-]*\"|'[]\[\(\)0-9a-zA-Z:/?#@!$&*+,;=.~_%^\-]*'))";
            };

            cursor = {
              style = "beam";
              beam-thickness = 1;
              # color = "000000 fcfad6";
            };
            mouse-bindings = {
              selection-override-modifiers = "Shift";
              primary-paste = "BTN_MIDDLE";
              select-begin = "BTN_LEFT";
              select-begin-block = "Control+BTN_LEFT";
              select-extend = "BTN_RIGHT";
              select-extend-character-wise = "Control+BTN_RIGHT";
              select-word = "BTN_LEFT-2";
              select-word-whitespace = "Control+BTN_LEFT-2";
            };
            # BlueberryPie
            # colors = {
            #   foreground = "babab9";
            #   background = "1c0c28";
            #   regular0 = "0a4c62";
            #   regular1 = "99246e";
            #   regular2 = "5cb1b3";
            #   regular3 = "eab9a8";
            #   regular4 = "90a5bd";
            #   regular5 = "9d54a7";
            #   regular6 = "7e83cc";
            #   regular7 = "f0e8d6";
            #   bright0 = "201637";
            #   bright1 = "c87272";
            #   bright2 = "0a6c7e";
            #   bright3 = "7a3188";
            #   bright4 = "39173d";
            #   bright5 = "bc94b7";
            #   bright6 = "5e6071";
            #   bright7 = "0a6c7e";
            #   selection-foreground = "ffffff";
            #   selection-background = "606060";
            # };

            # Dracula
            colors = {
              background = "282a36";
              foreground = "f8f8f2";

              ## Normal/regular colors (color palette 0-7);
              regular0 = "21222c"; # black
              regular1 = "ff5555"; # red
              regular2 = "50fa7b"; # green
              regular3 = "f1fa8c"; # yellow
              regular4 = "bd93f9"; # blue
              regular5 = "ff79c6"; # magenta
              regular6 = "8be9fd"; # cyan
              regular7 = "f8f8f2"; # white
              ## Bright colors (color palette 8-15)
              bright0 = "6272a4"; # bright black
              bright1 = "ff6e6e"; # bright red
              bright2 = "69ff94"; # bright green
              bright3 = "ffffa5"; # bright yellow
              bright4 = "d6acff"; # bright blue
              bright5 = "ff92df"; # bright magenta
              bright6 = "a4ffff"; # bright cyan
              bright7 = "ffffff"; # bright white
            };
          };
        };
      }
      # |----------------------------------------------------------------------| #
    ]);

    meta.maintainers = with localFlake.lib.maintainers; [czichy];
  }
