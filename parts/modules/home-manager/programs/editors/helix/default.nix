# --- parts/modules/home-manager/programs/editors/neovim.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles.hm
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
{ localFlake, inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel mkPywalEnableOption;

  cfg = config.tensorfiles.hm.programs.editors.helix;
  _ = mkOverrideAtHmModuleLevel;
in
{
  # TODO modularize config, cant be bothered to do it now
  options.tensorfiles.hm.programs.editors.helix = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the helix program.
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.shellAliases = {
        "helix" = _ "hx";
      };
      programs.helix = {
        enable = true;
        #Package = inputs.helix.packages.${pkgs.system}.default.overrideAttrs (self: {
        #  makeWrapperArgs = with pkgs;
        #    self.makeWrapperArgs
        #    or []
        #    ++ [
        #      "--suffix"
        #      "PATH"
        #      ":"
        #      (lib.makeBinPath [
        #        clang-tools
        #        marksman
        #        nil
        #        nodePackages.bash-language-server
        #        nodePackages.vscode-css-languageserver-bin
        #        nodePackages.vscode-langservers-extracted
        #        shellcheck
        #      ])
        #    ];
        #});
        settings.theme = "dracula";
        settings.editor = import ./editor.nix;
        settings.keys = import ./keys.nix;
        languages = import ./languages.nix { inherit config lib pkgs; };
        #themes = import ./theme.nix {inherit colorscheme;};
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [ czichy ];
}
