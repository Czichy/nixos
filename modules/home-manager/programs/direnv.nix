{localFlake}: {
  config,
  lib,
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
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.direnv = {
        enable = _ true;
        enableBashIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.bash");
        enableFishIntegration = _ (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.shells.fish");
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
            #
            "${config.home.homeDirectory}/Dokumente/finanzen/ledger"
          ];

          exact = ["$HOME/.envrc"];
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
