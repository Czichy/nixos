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

  cfg = config.tensorfiles.hm.programs.shells.zsh;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
  pathToRelative = strings.removePrefix "${config.home.homeDirectory}/";
in {
  options.tensorfiles.hm.programs.shells.zsh = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the zsh shell.
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

    p10k = {
      enable =
        mkEnableOption ''
          Whether to enable the powerlevel10k theme (and plugins) related
          code.
        ''
        // {
          default = true;
        };

      cfgSrc = mkOption {
        type = path;
        default = ./.;
        description = ''
          Path (or ideally, path inside a derivation) for the p10k.zsh
          configuration file

          Note: This should point just to the target directory. If you
          want to change the default filename of the `p10k.zsh` file,
          modify the cfgFile option.
        '';
      };

      cfgFile = mkOption {
        type = str;
        default = "p10k.zsh";
        description = ''
          Potential override of the p10k.zsh config filename.
        '';
      };
    };

    oh-my-zsh = {
      enable =
        mkEnableOption ''
          Whether to enable the oh-my-zsh framework related code
        ''
        // {
          default = true;
        };

      plugins = mkOption {
        type = listOf str;
        default = [
          "git"
          "git-flow"
          "colorize"
          "colored-man-pages"
        ];
        description = ''
          oh-my-zsh plugins that are enabled by default
        '';
      };

      withFzf = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether to enable the fzf plugin
        '';
      };
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
        [nitch]
        ++ (optional lsToEza eza)
        ++ (optional catToBat bat)
        ++ (optional findToFd fd)
        ++ (optional grepToRipgrep ripgrep)
        ++ (optional cfg.oh-my-zsh.withFzf fzf);

      programs.zsh = {
        enable = _ true;
        syntaxHighlighting.enable = _ true;
        autosuggestion.enable = _ cfg.withAutocompletions;
        history = {
          extended = _ false;
          expireDuplicatesFirst = _ true;
          ignoreAllDups = _ true;
          ignoreDups = _ true;
          ignoreSpace = _ true;
          size = _ 1000000;
          save = _ 1000000;
        };
        # historySubstringSearch = {
        #   enable = _ true;
        #};
        oh-my-zsh = mkIf cfg.oh-my-zsh.enable {
          enable = _ true;
          plugins = cfg.oh-my-zsh.plugins ++ (optional cfg.oh-my-zsh.withFzf "fzf");
        };
        plugins = [
          (mkIf cfg.withAutocompletions {
            name = "nix-zsh-completions";
            src = pkgs.nix-zsh-completions;
            file = "share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
          })
          (mkIf cfg.p10k.enable {
            name = "zsh-powerlevel10k";
            src = pkgs.zsh-powerlevel10k;
            file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
          })
          (mkIf cfg.p10k.enable {
            name = "powerlevel10k-config";
            src = cfg.p10k.cfgSrc;
            file = cfg.p10k.cfgFile;
          })
        ];
        loginExtra = _ "${pkgs.nitch}/bin/nitch";
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
    (mkIf ((isModuleLoadedAndEnabled config "tensorfiles.hm.programs.pywal") && cfg.pywal.enable) {
      programs.zsh.initExtra = mkBefore ''
        # Import colorscheme from 'wal' asynchronously
        # &   # Run the process in the background.
        # ( ) # Hide shell job control messages.
        (cat ${config.xdg.cacheHome}/wal/sequences &)
      '';
    })
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
      home.file."${config.xdg.cacheHome}/oh-my-zsh/.keep".enable = false;

      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        files =
          [".zsh_history"]
          ++ (optional cfg.oh-my-zsh.enable (pathToRelative "${config.xdg.cacheHome}/oh-my-zsh"))
          ++ (
            if cfg.p10k.enable
            then [
              (pathToRelative "${config.xdg.cacheHome}/p10k-dump-${config.home.username}.zsh")
              (pathToRelative "${config.xdg.cacheHome}/p10k-dump-${config.home.username}.zsh.zwc")
              (pathToRelative "${config.xdg.cacheHome}/p10k-instant-prompt-${config.home.username}.zsh")
              (pathToRelative "${config.xdg.cacheHome}/p10k-instant-prompt-${config.home.username}.zsh.zwc")
            ]
            else []
          );
        directories = optional cfg.p10k.enable (
          pathToRelative "${config.xdg.cacheHome}/p10k-${config.home.username}"
        );
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
