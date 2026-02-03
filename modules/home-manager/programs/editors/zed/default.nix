{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  system,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkOverrideAtHmModuleLevel
    mkPywalEnableOption
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    ;

  cfg = config.tensorfiles.hm.programs.editors.zed;
  _ = mkOverrideAtHmModuleLevel;
  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};
in {
  # TODO modularize config, cant be bothered to do it now
  options.tensorfiles.hm.programs.editors.zed = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the Zed Editor program.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };

    pywal = {
      enable = mkPywalEnableOption;
    };
  };

  imports = [
    ./language.nix
    ./lsp.nix
    ./extensions.nix
    ./editor.nix
  ];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.shellAliases = {
        "zed" = _ "zeditor";
      };
      home.sessionVariables = {
        GEMINI_API_KEY = "AIzaSyDhnUgG4pmseeru80h8ryBKI7isou9Q6e0";
      };

      xdg.configFile."zed/tasks.json" = {source = ./tasks.json;};
      programs.zed-editor = let
        bins = with pkgs; [
          nixd
          nixfmt-rfc-style
          prettierd
          nodejs
          nodePackages.prettier
          vscode-langservers-extracted
        ];
        libraries = with pkgs; [
          stdenv.cc.cc
          zlib
          openssl
        ];
      in {
        enable = true;
        userKeymaps = import ./keymaps.nix;
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          ".config/zed"
          ".local/share/zed"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
