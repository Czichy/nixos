{ config, pkgs, ... }:
{
  # workaround - until helix 23.10
  grammar = [ { use-grammars.except = [ "gemini" ]; } ];
  language = [
    # {
    # Use ltex-ls an an alternative LSP for Markdown, to provide spelling suggestions
    # https://github.com/helix-editor/helix/wiki/How-to-install-the-default-language-servers#markdown
    # name = "markdown";
    # language-servers = ["ltex-ls"];
    # text-width = 80;
    # }
    # {
    # Spellchecking in git https://github.com/helix-editor/helix/pull/7838
    # name = "git-commit";
    # language-servers = ["ltex-ls"];
    # }
    {
      name = "nix";
      auto-format = true;
      formatter = {
        command = "${pkgs.alejandra}/bin/alejandra";
        args = [ "-" ];
      };
    }
  ];

  language-server = {
    rust-analyzer = {
      command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      timeout = 120;
      config = {
        files = {
          excludeDirs = [ ".direnv" ];
          watcherExclude = [ ".direnv" ];
        };
        inlayHints = {
          bindingModeHints.enable = false;
          closingBraceHints.minLines = 10;
          closureReturnTypeHints.enable = "with_block";
          discriminantHints.enable = "fieldless";
          lifetimeElisionHints.enable = "skip_trivial";
          typeHints.hideClosureInitialization = false;
        };
        procMacro.enable = true;
        check = {
          allTargets = true;
          command = "clippy";
        };
      };
    };
    bash-language-server = {
      args = [ "start" ];
      command = "${pkgs.nodePackages.bash-language-server}/bin/bash-language-server";
    };
    ltex-ls = {
      command = "${pkgs.ltex-ls}/bin/ltex-ls";
    };
    nil = {
      command = "${pkgs.nil}/bin/nil";
    };
    terraform-ls = {
      args = [ "serve" ];
      command = "${pkgs.terraform-ls}/bin/terraform-ls";
    };
    vscode-json-language-server = {
      args = [ "--stdio" ];
      command = "${pkgs.nodePackages.vscode-json-languageserver}/bin/vscode-json-languageserver";
    };
  };
}
