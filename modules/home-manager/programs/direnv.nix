{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel isModuleLoadedAndEnabled;

  cfg = config.tensorfiles.hm.programs.direnv;
  _ = mkOverrideAtHmModuleLevel;
in {
  options.tensorfiles.hm.programs.direnv = with types; {
    enable = mkEnableOption ''
      Enables a HomeManager module that sets up direnv.

      References
      - https://github.com/direnv/direnv
    '';
    enableBashIntegration = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to enable Bash integration.
      '';
    };

    enableZshIntegration = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to enable Zsh integration.
      '';
    };

    enableFishIntegration = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to enable Fish integration. Note, enabling the direnv module
        will always active its functionality for Fish since the direnv package
        automatically gets loaded in Fish. If this is not the case try adding
        ```nix
          environment.pathsToLink = [ "/share/fish" ];
        ```
        to the system configuration.
      '';
    };

    enableNushellIntegration = mkOption {
      default = true;
      type = types.bool;
      description = ''
        Whether to enable Nushell integration.
      '';
    };

    nix-direnv = {
      enable = mkEnableOption ''
        [nix-direnv](https://github.com/nix-community/nix-direnv),
        a fast, persistent use_nix implementation for direnv'';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.direnv = {
        enable = _ true;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        # enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
        enableNushellIntegration = _ (
          isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.nushell"
        );
        enableZshIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.zsh");
        nix-direnv.enable = _ true;

        config.whitelist = {
          prefix = [
            "${config.home.homeDirectory}/projects/ibkr-rust"
            "${config.home.homeDirectory}/projects/nixos"
            "${config.home.homeDirectory}/projects/nixos-flake"
            "${config.home.homeDirectory}/projects/power-meter"
            "${config.home.homeDirectory}/projects/seeking-edge"
            "${config.home.homeDirectory}/projects/tradingjournalrs"
            "${config.home.homeDirectory}/projects/ibflex2ledger"
            #
            "${config.home.homeDirectory}/Dokumente/finanzen/ledger"
          ];

          exact = ["$HOME/.envrc"];
        };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      programs.bash.initExtra = mkIf cfg.enableBashIntegration (
        # Using mkAfter to make it more likely to appear after other
        # manipulations of the prompt.
        mkAfter ''
          eval "$(${pkgs.direnv}/bin/direnv hook bash)"
        ''
      );

      programs.zsh.initExtra = mkIf cfg.enableZshIntegration ''
        eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      '';

      programs.fish.interactiveShellInit = mkIf cfg.enableFishIntegration (
        # Using mkAfter to make it more likely to appear after other
        # manipulations of the prompt.
        mkAfter ''
          ${pkgs.direnv}/bin/direnv hook fish | source
        ''
      );

      programs.nushell.extraConfig = mkIf cfg.enableNushellIntegration (
        # Using mkAfter to make it more likely to appear after other
        # manipulations of the prompt.
        mkAfter ''
          # let-env config = ($env | default {} config).config
          # let-env config = ($env.config | default {} hooks)
          # let-env config = ($env.config | update hooks ($env.config.hooks | default [] pre_prompt))
          # let-env config = ($env.config | update hooks.pre_prompt ($env.config.hooks.pre_prompt | append {
          #   code: "
          #     let direnv = (${pkgs.direnv}/bin/direnv export json | from json)
          #     let direnv = if ($direnv | length) == 1 { $direnv } else { {} }
          #     $direnv | load-env
          #     "
          # }))
        ''
      );
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
