{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmModuleLevel
    isModuleLoadedAndEnabled
    mkPywalEnableOption
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.shells.fish;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in {
  imports = [
    ./tide.nix
    ./bindings.nix
  ];
  options.tensorfiles.hm.programs.shells.fish = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the fish shell.
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    withAutocompletions = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable autosuggestions/autocompletion related code
      '';
    };

    shellAliases = {
      lsToEza = mkOption {
        type = bool;
        default = true;
        description = ''
          Enable predefined shell aliases
        '';
      };

      catToBat = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the cat related commands to its reworked edition bat.
        '';
      };

      findToFd = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the find related commands to its reworked edition fd.
        '';
      };

      grepToRipgrep = mkOption {
        type = bool;
        default = true;
        description = ''
          Remap the find related commands to its reworked edition fd.
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = with pkgs;
      with cfg.shellAliases;
        [
          nitch
        ]
        ++ (optional lsToEza eza)
        ++ (optional catToBat bat)
        ++ (optional findToFd fd)
        ++ (optional grepToRipgrep ripgrep);

      programs.fish = {
        enable = _ true;
        shellAbbrs = {
          jqless = "jq -C | less -r";

          n = "nix";
          nd = "nix develop -c $SHELL";
          ns = "nix shell";
          nsn = "nix shell nixpkgs#";
          nb = "nix build";
          nbn = "nix build nixpkgs#";
          nf = "nix flake";

          nr = "nixos-rebuild --flake .";
          nrs = "nixos-rebuild --flake . switch";
          snr = "sudo nixos-rebuild --flake .";
          snrs = "sudo nixos-rebuild --flake . switch";
          hm = "home-manager --flake .";
          hms = "home-manager --flake . switch";

          # s = mkIf hasSpecialisationCli "specialisation";

          # ls = mkIf hasEza "eza";
          # exa = ls;

          # mutt = mkIf hasNeomutt "neomutt";
          # m = mutt;

          # aws-switch = mkIf hasAwsCli "export AWS_PROFILE=(aws configure list-profiles | fzf)";
          # awssw = aws-switch;
        };
        shellAliases = {
          # Clear screen and scrollback
          clear = "printf '\\033[2J\\033[3J\\033[1;1H'";
        };
        functions = {
          # Disable greeting
          fish_greeting = "";
          # Merge history when pressing up
          up-or-search = lib.readFile ./up-or-search.fish;
          # Check stuff in PATH
          nix-inspect =
            /*
            fish
            */
            ''
              set -s PATH | grep "PATH\[.*/nix/store" | cut -d '|' -f2 |  grep -v -e "-man" -e "-terminfo" | perl -pe 's:^/nix/store/\w{32}-([^/]*)/bin$:\1:' | sort | uniq
            '';
        };
        interactiveShellInit =
          /*
          fish
          */
          ''
            # Open command buffer in editor when alt+e is pressed
            bind \ee edit_command_buffer

            # Use terminal colors
            set -x fish_color_autosuggestion      brblack
            set -x fish_color_cancel              -r
            set -x fish_color_command             brgreen
            set -x fish_color_comment             brmagenta
            set -x fish_color_cwd                 green
            set -x fish_color_cwd_root            red
            set -x fish_color_end                 brmagenta
            set -x fish_color_error               brred
            set -x fish_color_escape              brcyan
            set -x fish_color_history_current     --bold
            set -x fish_color_host                normal
            set -x fish_color_host_remote         yellow
            set -x fish_color_match               --background=brblue
            set -x fish_color_normal              normal
            set -x fish_color_operator            cyan
            set -x fish_color_param               brblue
            set -x fish_color_quote               yellow
            set -x fish_color_redirection         bryellow
            set -x fish_color_search_match        'bryellow' '--background=brblack'
            set -x fish_color_selection           'white' '--bold' '--background=brblack'
            set -x fish_color_status              red
            set -x fish_color_user                brgreen
            set -x fish_color_valid_path          --underline
            set -x fish_pager_color_completion    normal
            set -x fish_pager_color_description   yellow
            set -x fish_pager_color_prefix        'white' '--bold' '--underline'
            set -x fish_pager_color_progress      'brwhite' '--background=cyan'
          '';
      };

      home.shellAliases = mkMerge [
        {fetch = _ "${pkgs.nitch}/bin/nitch";}
        (mkIf cfg.shellAliases.lsToEza {
          ls = _ "${pkgs.eza}/bin/eza";
          ll = _ "${pkgs.eza}/bin/eza -F --hyperlink --icons --group-directories-first -la --git --header --created --modified";
          tree = _ "${pkgs.eza}/bin/eza -F --hyperlink --icons --group-directories-first -la --git --header --created --modified -T";
        })
        (mkIf cfg.shellAliases.catToBat {
          cat = _ "${pkgs.bat}/bin/bat -p --wrap=never --paging=never";
          less = _ "${pkgs.bat}/bin/bat --paging=always";
        })
        (mkIf cfg.shellAliases.findToFd {
          find = _ "${pkgs.fd}/bin/fd";
          fd = _ "${pkgs.fd}/bin/fd";
        })
        (mkIf cfg.shellAliases.grepToRipgrep {grep = _ "${pkgs.ripgrep}/bin/rg";})
        {fetch = _ "${pkgs.nitch}/bin/nitch";}
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf cfg.shellAliases.catToBat {
      programs.bat = {
        enable = _ true;
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.shellAliases.grepToRipgrep {
      programs.ripgrep = {
        enable = _ true;
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.file."${config.xdg.cacheHome}/oh-my-fish/.keep".enable = false;

      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        files = [".local/share/fish"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
