# --- parts/modules/programs/shells/zsh/default.nix
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

  cfg = config.tensorfiles.hm.programs.shells.nushell;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  options.tensorfiles.hm.programs.shells.nushell = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the nushell.
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

    withAtuin = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable atuin related code
      '';
    };
    withZoxide = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to enable zoxide related code
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
          nushellPlugins.query
          nushellPlugins.gstat
          nushellPlugins.net
          nushellPlugins.formats
          nushellPlugins.polars
        ]
        ++ (optional lsToEza eza)
        ++ (optional catToBat bat)
        ++ (optional findToFd fd)
        ++ (optional grepToRipgrep ripgrep);

      programs.nushell = {
        enable = true;

        configFile.source = ./config.nu;
        envFile.source = ./env.nu;

        shellAliases = {
          # nix
          nixroots = "nix-store --gc --print-roots";
          # git
          gp = "git push";
          gps = "git push --set-upstream origin HEAD";
          gpf = "git push --force";
          gl = "git log --pretty=oneline --abbrev-commit";
          gb = "git branch";
          gbd = "git branch --delete --force";
          c = "git checkout";
          gpp = "git pull --prune";
          gsi = "git stash --include-untracked";
          gsp = "git stash pop";
          gsa = "git stage --all";
          gfu = "git fetch upstream";
          gmu = "git merge upstream/master master";
          gu = "git reset --soft HEAD~1";
          grh = "git reset --hard";
          # misc
          ll = "ls -la";
          e = "yazi";
          z = "zellij";
        };

        extraConfig = ''
          $env.config = ($env.config | merge {
               edit_mode: vi
               show_banner: false
             });

             plugin add ${pkgs.nushellPlugins.query}/bin/nu_plugin_query

             # maybe useful functions
             # use ${pkgs.nu_scripts}/share/nu_scripts/modules/formats/to-number-format.nu *
             # use ${pkgs.nu_scripts}/share/nu_scripts/sourced/api_wrappers/wolframalpha.nu *
             # use ${pkgs.nu_scripts}/share/nu_scripts/modules/background_task/job.nu *
             # use ${pkgs.nu_scripts}/share/nu_scripts/modules/network/ssh.nu *

             # completions
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/git/git-completions.nu *
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/btm/btm-completions.nu *
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/cargo/cargo-completions.nu *
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu *
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/tealdeer/tldr-completions.nu *
             use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/zellij/zellij-completions.nu *

            # alias
            use ${nu_scripts}/share/nu_scripts/aliases/git/git-aliases.nu *
            use ${nu_scripts}/share/nu_scripts/aliases/eza/eza-aliases.nu *
            use ${nu_scripts}/share/nu_scripts/aliases/bat/bat-aliases.nu *

             def gcb [name: string] {
               git checkout -b $name
             }

             def gc [name: string] {
               git checkout $name
             }

             def l [directory: string = "."] {
               ls -a $directory | select name size | sort-by size | reverse
             }

             def cl [directory: string] {
               cd $directory
               l
             }

             def gbs [] {
               let branch = (
                 git branch |
                 split row "\n" |
                 str trim |
                 where ($it !~ '\*') |
                 where ($it != "") |
                 str join (char nl) |
                 fzf --no-multi
               )
               if $branch != "" {
                 git switch $branch
               }
             }

             def ggc [] {
               git reflog expire --all --expire=now
               git gc --prune=now --aggressive
             }

             def nixgc [] {
               sudo /Users/raphael/dotfiles/result/sw/bin/nix-collect-garbage -d
               for file in (glob $'($env.HOME)/.local/state/nix/profiles/*') {
                 rm $file
               }
               nix store gc -v
             }
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
    (mkIf ((isModuleLoadedAndEnabled config "tensorfiles.hm.programs.pywal") && cfg.pywal.enable) {})
    # |----------------------------------------------------------------------| #
    (mkIf cfg.shellAliases.catToBat {
      programs.bat = {
        enable = _ true;
        config.theme = "base16";
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.shellAliases.grepToRipgrep {
      programs.ripgrep = {
        enable = _ true;
      };
    })

    # |----------------------------------------------------------------------| #
    (mkIf cfg.withAtuin {
      programs.atuin.enableNushellIntegration = true;
      programs.atuin = {
        enable = true;
        settings = {
          auto_sync = true;
          sync_frequency = "5m";
          # key_path = ;
          # sync_address = "http://atuin-atuin.tail68e9c.ts.net";
          sync.records = true;
        };
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf cfg.withZoxide {
      programs.zoxide = {
        enable = true;
        enableNushellIntegration = true;
        options = ["--cmd j"];
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}${config.home.homeDirectory}" = {
        directories = [
          ".local/share/atuin"
          ".local/share/zoxide"
        ];

        files = [".config/nushell/history.txt"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
