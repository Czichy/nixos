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
  inherit (localFlake.lib) mkOverrideAtHmModuleLevel mkPywalEnableOption;

  cfg = config.tensorfiles.hm.programs.editors.helix;
  _ = mkOverrideAtHmModuleLevel;
in {
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
        settings.theme = "onedark";
        settings.editor = import ./editor.nix;
        settings.keys = import ./keys.nix;
        languages = import ./languages.nix {inherit config lib pkgs;};
        #themes = import ./theme.nix {inherit colorscheme;};
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
