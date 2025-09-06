[
  # File panel (netrw)
  {
    "context" = "ProjectPanel && not_editing";
    "bindings" = {
      "z" = "outline_panel::CollapseAllEntries";
      "a" = "project_panel::NewFile";
      "d" = "project_panel::Delete";
      "r" = "project_panel::Rename";
      "x" = "project_panel::Cut";
      "y" = "project_panel::Copy";
      "p" = "project_panel::Paste";
      # Close
      "q" = "workspace::ToggleLeftDock";
    };
  }
  # Surround. Select word and press shift-s and add the surround
  # {
  #   "context" = "vim_mode == visual";
  #   "bindings" = {
  #     "shift-s" = [
  #       "vim::PushOperator"
  #       {
  #         "AddSurrounds" = {};
  #       }
  #     ];
  #   };
  # }
  # Terminal
  {
    "context" = "Terminal";
    "bindings" = {
      "ctrl-n" = "workspace::NewTerminal";
      # "ctrl-l" = "terminal::Clear";
      # "ctrl-s" = ["terminal::SendKeystroke" "ctrl-s"];
    };
  }
  # Visual or normal mode
  {
    "context" = "Editor && VimControl && !VimWaiting && !menu";
    "bindings" = {
      # # Git
      # "space g b" = "editor::ToggleGitBlame";
      # # Toggle inlay hints
      # "space t i" = "editor::ToggleInlayHints";
      # # Toggle indent guides
      # "space i g" = "editor::ToggleIndentGuides";
      # # Toggle soft wrap
      # "space u w" = "editor::ToggleSoftWrap";
      # # Toggle Zen mode
      # "space c z" = "workspace::ToggleCenteredLayout";
      # # Open markdown preview
      # "space m p" = "markdown::OpenPreviewToTheSide";
      # # Search word
      # "n" = "search::SelectNextMatch";
      # "shift-n" = "search::SelectPrevMatch";
      # # Go to file with `gf`
      # "space g f" = "editor::OpenExcerpts";
    };
  }
  # Normal mode
  # {
  #   "context" = "Editor && vim_mode == normal && !VimWaiting && !menu";
  #   "bindings" = {
  #     # Open recent project
  #     "space p p" = "projects::OpenRecent";
  #     # Close active panel
  #     "space q" = "pane::CloseActiveItem";
  #     "space f f" = ["file_finder::Toggle" {"separate_history" = true;}];
  #     # Move between panes
  #     # "ctrl-h" = ["workspace::ActivatePaneInDirection", "Left"];
  #     # "ctrl-l" = ["workspace::ActivatePaneInDirection", "Right"];
  #     # "ctrl-k" = ["workspace::ActivatePaneInDirection", "Up"];
  #     # "ctrl-j" = ["workspace::ActivatePaneInDirection", "Down"];
  #     # LSP
  #     "space g a" = "editor::ToggleCodeActions";
  #     "space r n" = "editor::Rename";
  #     "g d" = "editor::GoToDefinition";
  #     "g D" = "editor::GoToDefinitionSplit";
  #     "g i" = "editor::GoToImplementation";
  #     "g I" = "editor::GoToImplementationSplit";
  #     "g t" = "editor::GoToTypeDefinition";
  #     "g T" = "editor::GoToTypeDefinitionSplit";
  #     "g r" = "editor::FindAllReferences";
  #     "space k" = "editor::Hover";
  #     "ctrl-f" = "editor::Format";
  #     # Switch between buffers
  #     "ctrl-h" = "pane::ActivatePrevItem";
  #     "ctrl-l" = "pane::ActivateNextItem";
  #     # Save file
  #     "ctrl-s" = "workspace::Save";
  #     "space w" = "workspace::Save";
  #     # Show project panel with current file
  #     "space e" = "pane::RevealInProjectPanel";
  #     # Split panes
  #     "s v" = "pane::SplitRight";
  #     "s s" = "pane::SplitDown";
  #     # Open lazygit
  #     "space g g" = ["task::Spawn" {"task_name" = "GitUI";}];
  #   };
  # }
  # Empty pane, set of keybindings that are available when there is no active editor
  {
    "context" = "EmptyPane || SharedScreen";
    "bindings" = {
      # Open recent project
      "space p p" = "projects::OpenRecent";
    };
  }
  # Better escape
  # {
  #   "context" = "Editor && vim_mode == insert && !menu";
  #   "bindings" = {
  #     "j j" = "vim::NormalBefore"; # remap jj in insert mode to escape
  #     "j k" = "vim::NormalBefore"; # remap jk in insert mode to escape
  #   };
  # }
  # Panel nagivation
  {
    "context" = "Dock";
    "bindings" = {
      "ctrl-b" = "workspace::ToggleBottomDock";
      "ctrl-w h" = ["workspace::ActivatePaneInDirection" "Left"];
      "ctrl-w l" = ["workspace::ActivatePaneInDirection" "Right"];
      "ctrl-w k" = ["workspace::ActivatePaneInDirection" "Up"];
      "ctrl-w j" = ["workspace::ActivatePaneInDirection" "Down"];
    };
  }
  {
    "context" = "Editor && (showing_code_actions || showing_completions)";
    "bindings" = {
      "up" = "editor::ContextMenuPrevious";
      "ctrl-p" = "editor::ContextMenuPrevious";
      "down" = "editor::ContextMenuNext";
      "ctrl-n" = "editor::ContextMenuNext";
      "pageup" = "editor::ContextMenuFirst";
      "pagedown" = "editor::ContextMenuLast";
    };
  }
  # {
  #   "context" = "Workspace && os==linux";
  #   "bindings" = {
  #     "ctrl-alt-l" = "workspace::ToggleLeftDock";
  #     "ctrl-alt-r" = "workspace::ToggleRightDock";
  #   };
  # }
  {
    "context" = "Editor && vim_mode == helix_normal && !menu";
    "bindings" = {
      "space" = "vim::Space";
      "#" = "editor::ToggleComments";

      # "$" = "vim::EndOfLine";
      # "end" = "vim::EndOfLine";
      # "^" = "vim::FirstNonWhitespace";
      # "_" = "vim::StartOfLineDownward";
      # "g _" = "vim::EndOfLineDownward";
      # "shift-g" = "vim::EndOfDocument";
      # "{" = "vim::StartOfParagraph";
      # "}" = "vim::EndOfParagraph";
      # "(" = "vim::SentenceBackward";
      # ")" = "vim::SentenceForward";
      # "|" = "vim::GoToColumn";
      # "] ]" = "vim::NextSectionStart";
      # "] [" = "vim::NextSectionEnd";
      # "[ [" = "vim::PreviousSectionStart";
      # "[ ]" = "vim::PreviousSectionEnd";
      # "] m" = "vim::NextMethodStart";
      # "] M" = "vim::NextMethodEnd";
      # "[ m" = "vim::PreviousMethodStart";
      # "[ M" = "vim::PreviousMethodEnd";
      # "[ *" = "vim::PreviousComment";
      # "[ /" = "vim::PreviousComment";
      # "] *" = "vim::NextComment";
      # "] /" = "vim::NextComment";
      # # // Word motion;
      # "w" = "vim::NextWordStart";
      # "e" = "vim::NextWordEnd";
      # "b" = "vim::PreviousWordStart";
      # # // Subword motion;
      # # // "w"= "vim::NextSubwordStart";
      # # // "b"= "vim::PreviousSubwordStart";
      # # // "e"= "vim::NextSubwordEnd";
      # # // "g e"= "vim::PreviousSubwordEnd";
      # "shift-w" = ["vim::NextWordStart" {"ignore_punctuation" = true;}];
      # "shift-e" = ["vim::NextWordEnd" {"ignore_punctuation" = true;}];
      # "shift-b" = ["vim::PreviousWordStart" {"ignore_punctuation" = true;}];
      # "g shift-e" = ["vim::PreviousWordEnd" {"ignore_punctuation" = true;}];
      # "/" = "vim::Search";
      # "g /" = "pane::DeploySearch";
      # "?" = ["vim::Search" {"backwards" = true;}];
      # "*" = "vim::MoveToNext";
      # # "#" = "vim::MoveToPrevious";
      # "n" = "vim::MoveToNextMatch";
      # "shift-n" = "vim::MoveToPreviousMatch";
      # "%" = "vim::Matching";
      # "] }" = ["vim::UnmatchedForward" {"char" = "}";}];
      # "[ {" = ["vim::UnmatchedBackward" {"char" = "{";}];
      # "] )" = ["vim::UnmatchedForward" {"char" = ")";}];
      # "[ (" = ["vim::UnmatchedBackward" {"char" = "(";}];
      # "f" = [
      #   "vim::PushFindForward"
      #   {
      #     "before" = false;
      #     "multiline" = false;
      #   }
      # ];
      # "t" = [
      #   "vim::PushFindForward"
      #   {
      #     "before" = true;
      #     "multiline" = false;
      #   }
      # ];
      # "shift-f" = [
      #   "vim::PushFindBackward"
      #   {
      #     "after" = false;
      #     "multiline" = false;
      #   }
      # ];
      # "shift-t" = [
      #   "vim::PushFindBackward"
      #   {
      #     "after" = true;
      #     "multiline" = false;
      #   }
      # ];
      # "m" = "vim::PushMark";
      # "'" = ["vim::PushJump" {"line" = true;}];
      # "`" = ["vim::PushJump" {"line" = false;}];
      # ";" = "vim::RepeatFind";
      # "," = "vim::RepeatFindReversed";
      # "ctrl-o" = "pane::GoBack";
      # "ctrl-i" = "pane::GoForward";
      # "ctrl-]" = "editor::GoToDefinition";
      # "v" = "vim::ToggleVisual";
      # "shift-v" = "vim::ToggleVisualLine";
      # "ctrl-v" = "vim::ToggleVisualBlock";
      # "ctrl-q" = "vim::ToggleVisualBlock";
      # "shift-k" = "editor::Hover";
      # "shift-r" = "vim::ToggleReplace";
      # "0" = "vim::StartOfLine";
      # "home" = "vim::StartOfLine";
      # "ctrl-f" = "vim::PageDown";
      # "pagedown" = "vim::PageDown";
      # "ctrl-b" = "vim::PageUp";
      # "pageup" = "vim::PageUp";
      # "ctrl-d" = "vim::ScrollDown";
      # "ctrl-u" = "vim::ScrollUp";
      # "ctrl-e" = "vim::LineDown";
      # "ctrl-y" = "vim::LineUp";
      # # // "g" command;
      # "g g" = "vim::StartOfDocument";
      # "g d" = "editor::GoToDefinition";
      # "g shift-d" = "editor::GoToDeclaration";
      # "g shift-i" = "editor::GoToImplementation";
      # "g x" = "editor::OpenUrl";
      # "g f" = "editor::OpenFile";
      # "g shift-l" = "vim::SelectPrevious";
      # "g >" = ["editor::SelectNext" {"replace_newest" = true;}];
      # "g <" = ["editor::SelectPrevious" {"replace_newest" = true;}];
      # "g a" = "editor::SelectAllMatches";
      # "g shift-s" = "project_symbols::Toggle";
      # "g ." = "editor::ToggleCodeActions";
      # "g shift-a" = "editor::FindAllReferences";
      # "g space" = "editor::OpenExcerpts";
      # "g *" = ["vim::MoveToNext" {"partial_word" = true;}];
      # "g #" = ["vim::MoveToPrevious" {"partial_word" = true;}];
      # "g j" = ["vim::Down" {"display_lines" = true;}];
      # "g down" = ["vim::Down" {"display_lines" = true;}];
      # "g k" = ["vim::Up" {"display_lines" = true;}];
      # "g up" = ["vim::Up" {"display_lines" = true;}];
      # "g $" = ["vim::EndOfLine" {"display_lines" = true;}];
      # "g end" = ["vim::EndOfLine" {"display_lines" = true;}];
      # "g 0" = ["vim::StartOfLine" {"display_lines" = true;}];
      # "g home" = ["vim::StartOfLine" {"display_lines" = true;}];
      # "g ^" = ["vim::FirstNonWhitespace" {"display_lines" = true;}];
      # "g v" = "vim::RestoreVisualSelection";
      # "g ]" = "editor::GoToDiagnostic";
      # "g [" = "editor::GoToPreviousDiagnostic";
      # "g i" = "vim::InsertAtPrevious";
      # "g ," = "vim::ChangeListNewer";
      # "g ;" = "vim::ChangeListOlder";
      # "shift-h" = "vim::WindowTop";
      # "shift-m" = "vim::WindowMiddle";
      # "shift-l" = "vim::WindowBottom";
      # "q" = "vim::ToggleRecord";
      # "shift-q" = "vim::ReplayLastRecording";
      # "@" = "vim::PushReplayRegister";
      # # // z command;
      # "z enter" = ["workspace::SendKeystrokes" "z t ^"];
      # "z -" = ["workspace::SendKeystrokes" "z b ^"];
      # "z ^" = ["workspace::SendKeystrokes" "shift-h k z b ^"];
      # "z +" = ["workspace::SendKeystrokes" "shift-l j z t ^"];
      # "z t" = "editor::ScrollCursorTop";
      # "z z" = "editor::ScrollCursorCenter";
      # "z ." = ["workspace::SendKeystrokes" "z z ^"];
      # "z b" = "editor::ScrollCursorBottom";
      # "z a" = "editor::ToggleFold";
      # "z shift-a" = "editor::ToggleFoldRecursive";
      # "z c" = "editor::Fold";
      # "z shift-c" = "editor::FoldRecursive";
      # "z o" = "editor::UnfoldLines";
      # "z shift-o" = "editor::UnfoldRecursive";
      # "z f" = "editor::FoldSelectedRanges";
      # "z shift-m" = "editor::FoldAll";
      # "z shift-r" = "editor::UnfoldAll";
      # "shift-z shift-q" = ["pane::CloseActiveItem" {"save_intent" = "skip";}];
      # "shift-z shift-z" = [
      #   "pane::CloseActiveItem"
      #   {"save_intent" = "save_all";}
      # ];
      # # // Count suppor;
      # "1" = ["vim::Number" 1];
      # "2" = ["vim::Number" 2];
      # "3" = ["vim::Number" 3];
      # "4" = ["vim::Number" 4];
      # "5" = ["vim::Number" 5];
      # "6" = ["vim::Number" 6];
      # "7" = ["vim::Number" 7];
      # "8" = ["vim::Number" 8];
      # "9" = ["vim::Number" 9];
      # "ctrl-w d" = "editor::GoToDefinitionSplit";
      # "ctrl-w g d" = "editor::GoToDefinitionSplit";
      # "ctrl-w shift-d" = "editor::GoToTypeDefinitionSplit";
      # "ctrl-w g shift-d" = "editor::GoToTypeDefinitionSplit";
      # "ctrl-w space" = "editor::OpenExcerptsSplit";
      # "ctrl-w g space" = "editor::OpenExcerptsSplit";
      # "ctrl-6" = "pane::AlternateFile";

      # "escape" = "editor::Cancel";
      # "ctrl-[" = "editor::Cancel";
      # ":" = "command_palette::Toggle";
      # "." = "vim::Repeat";
      # "shift-d" = "vim::DeleteToEndOfLine";
      # "shift-j" = "vim::JoinLines";
      # "y" = "editor::Copy";
      # "shift-y" = "vim::YankLine";
      # "i" = "vim::InsertBefore";
      # "shift-i" = "vim::InsertFirstNonWhitespace";
      # "a" = "vim::InsertAfter";
      # "shift-a" = "vim::InsertEndOfLine";
      # "x" = "vim::DeleteRight";
      # "shift-x" = "vim::DeleteLeft";
      # "o" = "vim::InsertLineBelow";
      # "shift-o" = "vim::InsertLineAbove";
      # "~" = "vim::ChangeCase";
      # "ctrl-a" = "vim::Increment";
      # "ctrl-x" = "vim::Decrement";
      # "p" = "vim::Paste";
      # "shift-p" = ["vim::Paste" {"before" = true;}];
      # "u" = "vim::Undo";
      # "ctrl-r" = "vim::Redo";
      # "r" = "vim::PushReplace";
      # "s" = "vim::Substitute";
      # "shift-s" = "vim::SubstituteLine";
      # ">" = "vim::PushIndent";
      # "<" = "vim::PushOutdent";
      # "=" = "vim::PushAutoIndent";
      # "g u" = "vim::PushLowercase";
      # "g shift-u" = "vim::PushUppercase";
      # "g ~" = "vim::PushOppositeCase";
      # "\"" = "vim::PushRegister";
      # "g q" = "vim::PushRewrap";
      # "g w" = "vim::PushRewrap";
      # "ctrl-pagedown" = "pane::ActivateNextItem";
      # "ctrl-pageup" = "pane::ActivatePreviousItem";
      # "insert" = "vim::InsertBefore";
      # # // tree-sitter related command;
      # "[ x" = "editor::SelectLargerSyntaxNode";
      # "] x" = "editor::SelectSmallerSyntaxNode";
      # "] d" = "editor::GoToDiagnostic";
      # "[ d" = "editor::GoToPreviousDiagnostic";
      # "] c" = "editor::GoToHunk";
      # "[ c" = "editor::GoToPreviousHunk";
      # # // Goto mod;
      # "g n" = "pane::ActivateNextItem";
      # "g p" = "pane::ActivatePreviousItem";
      # # // "tab"= "pane::ActivateNextItem";
      # # // "shift-tab"= "pane::ActivatePrevItem";
      # "H" = "pane::ActivatePreviousItem";
      # "L" = "pane::ActivateNextItem";
      # "g l" = "vim::EndOfLine";
      # "g h" = "vim::StartOfLine";
      # "g s" = "vim::FirstNonWhitespace";
      # # // "g s" default behavior is "space s;
      # "g e" = "vim::EndOfDocument";
      # "g y" = "editor::GoToTypeDefinition";
      # "g r" = "editor::FindAllReferences"; #// zed specifi;
      # "g t" = "vim::WindowTop";
      # "g c" = "vim::WindowMiddle";
      # "g b" = "vim::WindowBottom";
      # # // Window mod;
      # "space w h" = "workspace::ActivatePaneLeft";
      # "space w l" = "workspace::ActivatePaneRight";
      # "space w k" = "workspace::ActivatePaneUp";
      # "space w j" = "workspace::ActivatePaneDown";
      # "space w q" = "pane::CloseActiveItem";
      # "space w s" = "pane::SplitRight";
      # "space w r" = "pane::SplitRight";
      # "space w v" = "pane::SplitDown";
      # "space w d" = "pane::SplitDown";
      # # // Space mod;
      # "space f" = "file_finder::Toggle";
      # "space k" = "editor::Hover";
      # "space s" = "outline::Toggle";
      # "space shift-s" = "project_symbols::Toggle";
      # "space d" = "editor::GoToDiagnostic";
      # "space shift-d" = "diagnostics::Deploy";
      # "space r" = "editor::Rename";
      # "space a" = "editor::ToggleCodeActions";
      # "space h" = "editor::SelectAllMatches";
      # "space y" = "editor::Copy";
      # "space p" = "editor::Paste";
      # # // Match mod;
      # "m m" = "vim::Matching";
      # "m i w" = ["workspace::SendKeystrokes" "v i w"];
      # # // Mis;
      # "ctrl-k" = "editor::MoveLineUp";
      # "ctrl-j" = "editor::MoveLineDown";
      # # // "ctrl-v"= "editor::Paste";
      # "shift-u" = "editor::Redo";
      # "ctrl-c" = "editor::ToggleComments";
      # # "d" = ["workspace::SendKeystrokes" "y d"];
      # "c" = ["workspace::SendKeystrokes" "d i"];
    };
  }
  {
    "context" = "Editor && (vim_mode != helix_normal || vim_mode != visual) && !VimWaiting";
    "bindings" = {
      "escape" = "vim::SwitchToHelixNormalMode";
      # "ctrl-j" = "vim::SwitchToHelixNormalMode";
      # // "escape"= ["vim::HelixNormalAfter"]
    };
  }
  {
    "context" = "Editor && (vim_mode == helix_normal || vim_mode == visual)";
    "bindings" = {
      "escape" = "editor::Cancel";
      # "w" = "vim::NextWordStart";
      # "e" = "vim::NextWordEnd";
      # "b" = "vim::PreviousWordStart";
      # "/" = "vim::Search";
      # "%" = "editor::SelectAll";
      # "y" = "vim::VisualYank";
      # "p" = "vim::Paste";
      # "o" = "vim::InsertLineBelow";
      # "O" = "vim::InsertLineAbove";
      # "x" = "editor::SelectLine";
      # "u" = "vim::Undo";
      # "i" = "vim::InsertBefore";
      # "I" = ["workspace::SendKeystrokes" "g h i"];
      # "a" = "vim::InsertAfter";
      # "d" = "vim::HelixDelete";
      # "A" = "vim::InsertEndOfLine";
      # "R" = "vim::PushReplace";
      # "c" = ["workspace::SendKeystrokes" "d i"];
      # ">" = "editor::Tab";
      # "<" = "editor::Backtab";
      # # // Alt
      # "alt-d" = "vim::VisualDelete";
      # "alt-j" = "editor::MoveLineDown";
      # "alt-k" = "editor::MoveLineUp";
      # # // Ctrl
      # "ctrl-f" = "vim::PageDown";
      # "ctrl-b" = "vim::PageUp";
      # "ctrl-o" = "pane::GoBack";
      # "ctrl-i" = "pane::GoForward";
      # "ctrl-d" = "vim::ScrollDown";
      # "ctrl-u" = "vim::ScrollUp";
      # "ctrl-l" = "editor::DeleteToEndOfLine";
      # "ctrl-A" = "editor::ConvertToUpperCase";
      # "ctrl-x" = "editor::ShowCompletions";
      # "ctrl-c" = "editor::Copy";
      # # "ctrl-v" = "editor::Paste";
      # # "ctrl-w" = "pane::CloseActiveItem";
      # "ctrl-s" = "workspace::Save";
      # # // "g" commands
      # "g a" = "tab_switcher::Toggle";
      # "g e" = "editor::MoveToEnd";
      # "g g" = "vim::StartOfDocument";
      # "g d" = "editor::GoToDefinition";
      # "g h" = "vim::StartOfLine";
      # "g l" = "vim::EndOfLine";
      # "g r" = "editor::FindAllReferences";
      # "g t" = "go_to_line::Toggle";
      # "g y" = "editor::GoToDefinition";
      # "g i" = "editor::GoToImplementation";
      # # // Space mode
      # "space /" = "workspace::NewSearch";
      # "space e" = "pane::RevealInProjectPanel";
      # "space f" = "file_finder::Toggle";
      # "space k" = "editor::Hover";
      # "space s" = "outline::Toggle";
      # "space S" = "project_symbols::Toggle";
      # "space d" = "editor::GoToDiagnostic";
      # "space D" = "diagnostics::Deploy";
      # "space r" = "editor::Rename";
      # "space a" = "editor::ToggleCodeActions";
      # "space h" = "editor::SelectAllMatches";
      # "space c" = "editor::ToggleComments";
      # "space y" = "editor::Copy";
      # "space p" = "editor::Paste";
      # # // Unimpaired
      # "] f" = "vim::NextMethodStart";
      # "[ f" = "vim::PreviousMethodStart";
    };
  }
  # {
  #   "context" = "Editor && vim_mode == insert";
  #   "bindings" = {
  #     "ctrl-s" = "workspace::Save";
  #     "ctrl-x" = "editor::ShowCompletions";
  #     "ctrl-f" = "vim::PageDown";
  #     "ctrl-b" = "vim::PageUp";
  #     "ctrl-o" = "pane::GoBack";
  #     "ctrl-i" = "pane::GoForward";
  #     "ctrl-v" = "editor::Paste";
  #     "ctrl-u" = "editor::DeleteToBeginningOfLine";
  #     "ctrl-l" = "editor::DeleteToEndOfLine";
  #     "alt-d" = "editor::DeleteToNextWordEnd";
  #   };
  # }
]
