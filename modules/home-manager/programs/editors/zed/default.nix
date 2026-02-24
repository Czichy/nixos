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

  hasAnthropicSecret = config.age.secrets ? anthropic_api_key;

  # Wrapper script that ensures ANTHROPIC_API_KEY is set before launching Zed
  zeditor-wrapped = pkgs.writeShellScriptBin "zeditor-wrapped" ''
    if [ -z "$ANTHROPIC_API_KEY" ]; then
      ANTHROPIC_API_KEY="$(cat ${
        if hasAnthropicSecret
        then config.age.secrets.anthropic_api_key.path
        else "/dev/null"
      } 2>/dev/null | tr -d '[:space:]')"
      export ANTHROPIC_API_KEY
    fi
    exec ${pkgs.zed-editor}/bin/zeditor "$@"
  '';
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
      home.packages = lib.optional hasAnthropicSecret zeditor-wrapped;

      home.shellAliases = {
        "zed" = _ (
          if hasAnthropicSecret
          then "zeditor-wrapped"
          else "zeditor"
        );
      };

      xdg.desktopEntries.zed = {
        name = "Zed";
        comment = "A high-performance, multiplayer code editor";
        exec =
          if hasAnthropicSecret
          then "zeditor-wrapped --foreground %F"
          else "zeditor --foreground %F";
        icon = "zed";
        terminal = false;
        type = "Application";
        categories = ["TextEditor" "Development" "IDE"];
        mimeType = ["text/plain" "inode/directory"];
        startupNotify = true;
        settings = {
          Keywords = "zed;editor;code;";
        };
      };

      xdg.configFile."zed/tasks.json" = {source = ./tasks.json;};
      programs.zed-editor = let
        bins = with pkgs; [
          nixd
          nixfmt
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
