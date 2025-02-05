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
    isModuleLoadedAndEnabled
    mkPywalEnableOption
    mkDummyDerivation
    ;

  cfg = config.tensorfiles.hm.programs.editors.zed;
  _ = mkOverrideAtHmModuleLevel;

  pywalCheck = (isModuleLoadedAndEnabled config "tensorfiles.hm.programs.pywal") && cfg.pywal.enable;
in {
  # TODO modularize config, cant be bothered to do it now
  options.tensorfiles.hm.programs.editors.zed = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the Zed Editor program.
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.shellAliases = {
        "zed" = _ "zed-editor";
      };
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
        extensions = [
          "nix"
          "xy-zed" # a gorgeous dark theme
        ];
        # package = with pkgs; writeShellScriptBin "zed" ''
        #   export PATH=${lib.makeBinPath bins}:$PATH
        #   export LD_LIBRARY_PATH=${lib.makeLibraryPath libraries}
        #   export NIX_LD_LIBRARY_PATH=${lib.makeLibraryPath libraries}
        #   export NIX_LD=${stdenv.cc.bintools.dynamicLinker}
        #   exec ${zed-editor}/bin/zed "$@"
        # '';
        userSettings = {
          features = {
            copilot = true;
            inline_completion_provider = "copilot";
          };
          assistant = {
            version = "2";
            default_model = {
              provider = "anthropic";
              model = "claude-3-5-sonnet-latest";
            };
          };
          lsp = {
            rust-analyzer = {
              binary = {path_lookup = true;};
            };
          };
          telemetry = {
            metrics = false;
          };
          vim_mode = true;
          ui_font_size = 16;
          buffer_font_size = 16;
          theme = {
            mode = "system";
            light = "Andromeda";
            dark = "One Dark";
          };
          ssh_connections = [
            {
              # host = "trex.satanic.link";
            }
          ];
        };
        userKeymaps = [
          {bindings = {up = "menu::SelectPrev";};}
          {
            context = "Editor";
            bindings = {escape = "editor::Cancel";};
          }
        ];
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
