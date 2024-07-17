# --- parts/modules/home-manager/programs/direnv.nix
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
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib.tensorfiles) mkOverrideAtHmModuleLevel isModuleLoadedAndEnabled;

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
            "${config.home.homeDirectory}/projects/tradingjournalrs"
            "${config.home.homeDirectory}/projects/seeking-edge"
            "${config.home.homeDirectory}/projects/ibkr_rust"
            "${config.home.homeDirectory}/projects/nixos-flake"
            "${config.home.homeDirectory}/projects/nixos"
            "${config.home.homeDirectory}/Dokumente/finanzen/ledger"
          ];

          exact = ["$HOME/.envrc"];
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
