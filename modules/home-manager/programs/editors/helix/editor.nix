{
  cursorline = true;
  auto-save = true;
  line-number = "relative";
  color-modes = true;
  file-picker.hidden = false;
  indent-guides = {
    render = true;
    character = "╎";
    rainbow-option = "dim";
  };
  # smart-tab.enable = true;
  soft-wrap.enable = false;
  cursor-shape = {
    insert = "bar";
    normal = "block";
    select = "underline";
  };
  whitespace.render = {
    space = "none";
    tab = "none";
    newline = "all";
  };
  whitespace.characters = {
    newline = "↩";
  };
  lsp = {
    display-messages = true;
    display-inlay-hints = true;
    snippets = true;
  };
  statusline = {
    right = [
      "diagnostics"
      "selections"
      "position"
      "file-encoding"
      "spacer"
      "version-control"
      "spacer"
    ];
  };
}
