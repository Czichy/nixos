{
  programs.zed-editor.userSettings = {
    # Language Server Protocol (LSP)
    lsp = {
      nix = {
        binary = {
          path_lookup = true;
        };
      };
      rust-analyzer = {
        binary = {path_lookup = true;};
        initialization_options = {
          check = {
            command = "clippy";
          };
          cargo = {
            allFeatures = true;
            loadOutDirsFromCheck = true;
            buildScripts = {
              enable = true;
            };
          };
          procMacro = {
            enable = true;
            ignored = {
              async-trait = ["async_trait"];
              napi-derive = ["napi"];
              async-recursion = ["async_recursion"];
            };
          };
          rust = {
            analyzerTargetDir = true;
          };
          inlayHints = {
            maxLength = null;
            lifetimeElisionHints = {
              enable = "skip_trivial";
              useParameterNames = true;
            };
            closureReturnTypeHints = {
              enable = "always";
            };
          };
        };
      };
    };
  };
}
