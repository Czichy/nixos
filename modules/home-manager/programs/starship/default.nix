{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  # inherit (localFlake.lib) mkOverrideAtHmModuleLevel;
  cfg = config.tensorfiles.hm.programs.starship;
in {
  options.tensorfiles.hm.programs.starship = with types; {
    enable = mkEnableOption ''
      TODO
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.starship = let
        # macchiatoPreset = import ./macchiato.nix { inherit pkgs; };
        # rosePinePreset = import ./rosePine.nix { inherit pkgs; };
        tokyoPreset = import ./tokyo.nix {inherit pkgs;};
      in {
        enable = true;
        enableNushellIntegration = true;
        enableFishIntegration = true;
        settings = tokyoPreset;
        enableTransience = true;
      };
      # enable = true;
      # settings = {
      #   # Transliteration of https://github.com/starship/starship/blob/master/docs
      #   # /public/presets/toml/pastel-powerline.toml
      #   # Heavily modified but under original ISC license.
      #   add_newline = false;
      #   format = lib.concatStrings [
      #     "[](color_orange)"
      #     "$os"
      #     "$username"
      #     "[](bg:color_yellow fg:color_orange)"
      #     "$directory"
      #     "[](fg:color_yellow bg:color_aqua)"
      #     "$git_branch"
      #     "$git_status"
      #     "[](fg:color_aqua bg:color_bg1)"
      #     "$character"
      #     "[ ](fg:color_bg1)"
      #   ];
      #   palette = "solarized_dark";
      #   palettes.solarized_dark = {
      #     color_fg0 = "#eee8d5";
      #     color_bg1 = "#073642";
      #     color_bg3 = "#586e75";
      #     color_blue = "#268bd2";
      #     color_aqua = "#2aa198";
      #     color_green = "#859900";
      #     color_orange = "#cb4b16";
      #     color_purple = "#6c71c4";
      #     color_red = "#dc322f";
      #     color_yellow = "#b58900";
      #   };
      #   os = {
      #     disabled = false;
      #     style = "bg:color_orange fg:color_fg0";
      #     symbols = {
      #       Ubuntu = "󰕈";
      #       Linux = "󰌽";
      #       Macos = "󰀵";
      #       NixOS = "";
      #     };
      #   };
      #   username = {
      #     show_always = true;
      #     style_user = "bg:color_orange fg:color_fg0";
      #     style_root = "bg:color_orange fg:color_fg0";
      #     format = "[ $user ]($style)";
      #   };
      #   directory = {
      #     style = "fg:color_fg0 bg:color_yellow";
      #     format = "[ $path ]($style)";
      #     truncation_length = 0;
      #     truncation_symbol = "…/";
      #     substitutions = {
      #       "Documents" = "󰈙 ";
      #       "Downloads" = " ";
      #       "Music" = "󰝚 ";
      #       "Pictures" = " ";
      #       "Developer" = "󰲋 ";
      #     };
      #   };
      #   git_branch = {
      #     symbol = "";
      #     style = "bg:color_aqua";
      #     format = "[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)";
      #   };
      #   git_status = {
      #     style = "bg:color_aqua";
      #     format = "[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)";
      #   };
      #   line_break = {
      #     disabled = true;
      #   };
      #   character = {
      #     disabled = false;
      #     format = "[ ](bg:color_bg1)$symbol";
      #     success_symbol = "[#](fg:color_aqua bg:color_bg1)";
      #     error_symbol = "[#](fg:color_red bg:color_bg1)";
      #     vimcmd_symbol = "[#](fg:color_green bg:color_bg1)";
      #     vimcmd_replace_one_symbol = "[#](fg:color_purple bg:color_bg1)";
      #     vimcmd_replace_symbol = "[#](fg:color_purple bg:color_bg1)";
      #     vimcmd_visual_symbol = "[#](fg:color_yellow bg:color_bg1)";
      #   };
      # };
      # settings = {
      #   format = let
      #     git = "$git_branch$git_commit$git_state$git_status";
      #     cloud = "$aws$gcloud$openstack";
      #   in ''
      #     $username$hostname($shlvl)($cmd_duration) $fill ($nix_shell)$custom
      #     $directory(${git})(- ${cloud}) $fill $time
      #     $jobs$character
      #   '';

      #   fill = {
      #     symbol = " ";
      #     disabled = false;
      #   };

      #   # Core
      #   username = {
      #     format = "[$user]($style)";
      #     show_always = true;
      #   };
      #   hostname = {
      #     format = "[@$hostname]($style) ";
      #     ssh_only = false;
      #     style = "bold green";
      #   };
      #   shlvl = {
      #     format = "[$shlvl]($style) ";
      #     style = "bold cyan";
      #     threshold = 2;
      #     repeat = true;
      #     disabled = false;
      #   };
      #   cmd_duration = {
      #     format = "took [$duration]($style) ";
      #   };

      #   directory = {
      #     format = "[$path]($style)( [$read_only]($read_only_style)) ";
      #   };
      #   nix_shell = {
      #     format = "[($name \\(develop\\) <- )$symbol]($style) ";
      #     impure_msg = "";
      #     symbol = " ";
      #     style = "bold red";
      #   };
      #   # custom = {
      #   #   nix_inspect = {
      #   #     disabled = false;
      #   #     when = "test -z $IN_NIX_SHELL";
      #   #     command = "${nix-inspect}/bin/nix-inspect kitty imagemagick ncurses";
      #   #     format = "[($output <- )$symbol]($style) ";
      #   #     symbol = " ";
      #   #     style = "bold blue";
      #   #   };
      #   # };

      #   character = {
      #     error_symbol = "[~~>](bold red)";
      #     success_symbol = "[->>](bold green)";
      #     vimcmd_symbol = "[<<-](bold yellow)";
      #     vimcmd_visual_symbol = "[<<-](bold cyan)";
      #     vimcmd_replace_symbol = "[<<-](bold purple)";
      #     vimcmd_replace_one_symbol = "[<<-](bold purple)";
      #   };

      #   time = {
      #     format = "\\\[[$time]($style)\\\]";
      #     disabled = false;
      #   };

      #   # Cloud
      #   gcloud = {
      #     format = "on [$symbol$active(/$project)(\\($region\\))]($style)";
      #   };
      #   aws = {
      #     format = "on [$symbol$profile(\\($region\\))]($style)";
      #   };

      #   # Icon changes only \/
      #   aws.symbol = "  ";
      #   conda.symbol = " ";
      #   dart.symbol = " ";
      #   directory.read_only = " ";
      #   docker_context.symbol = " ";
      #   elixir.symbol = " ";
      #   elm.symbol = " ";
      #   gcloud.symbol = " ";
      #   git_branch.symbol = " ";
      #   golang.symbol = " ";
      #   hg_branch.symbol = " ";
      #   java.symbol = " ";
      #   julia.symbol = " ";
      #   memory_usage.symbol = " ";
      #   nim.symbol = " ";
      #   nodejs.symbol = " ";
      #   package.symbol = " ";
      #   perl.symbol = " ";
      #   php.symbol = " ";
      #   python.symbol = " ";
      #   ruby.symbol = " ";
      #   rust.symbol = " ";
      #   scala.symbol = " ";
      #   shlvl.symbol = "";
      #   swift.symbol = "ﯣ ";
      #   terraform.symbol = "行";
      # };
      # };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
