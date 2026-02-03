{pkgs, ...}: {
  programs.zed-editor = {
    package = pkgs.zed-editor-fhs;
    extensions = [
      "basher"
      "cargotoml"
      "catppuccin"
      "catppuccin-icons"
      "git-firefly"
      "jj-lsp"
      "marksman"
      "nix"
      "snippets"
      "toml"
      "typos"
      "xy-zed" # a gorgeous dark theme
      "zig"
    ];
    # Automatically Installed Extensions
    userSettings.auto_install_extensions = {
      base16 = true;
      basher = false;
      csv = true;
      dbml = false;
      git-firefly = true;
      html = true;
      just = false;
      latex = true;
      markdown-oxide = false;
      mermaid = false;
      nix = true;
      pylsp = true;
      python-refactoring = true;
      rainbow-csv = true;
      ruff = true;
      sagemath = false;
      snippets = true;
      sql = true;
      toml = true;
      typst = true;
      tokyo-night = true;
      vscode-icons = true;
    };
  };
}
