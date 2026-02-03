{
  programs.zed-editor.userSettings = {

          helix_mode = true;
          restore_on_startup = "last_workspace";
          show_onboarding_banner = false;

          # Indent Guides
          "indent_guides" = {
            "enabled" = true;
            "line_width" = 2; # Pixels, between 1 and 10.
            "active_line_width" = 3; # Pixels, between 1 and 10.
            "coloring" = "indent_aware"; # "disabled", "fixed", "indent_aware"
            "background_coloring" = "disabled"; # "disabled", "indent_aware"
          };

          # Whether the editor will scroll beyond the last line.
          "scroll_beyond_last_line" = "one_page";
          # The number of lines to keep above/below the cursor when scrolling.
          "vertical_scroll_margin" = 3;
          # Scroll sensitivity multiplier. This multiplier is applied
          # to both the horizontal and vertical delta values while scrolling.
          "scroll_sensitivity" = 1.0;

          # Search
          "search" = {
            "whole_word" = false;
            "case_sensitive" = false;
            "include_ignored" = false;
            "regex" = false;
          };
          # If 'search_wrap' is disabled, search result do not wrap around the end of the file.
          "search_wrap" = true;
          # When to populate a new search's query based on the text under the cursor.
          # This setting can take the following three values:
          #
          # 1. Always populate the search query with the word under the cursor (default).
          #    "always"
          # 2. Only populate the search query when there is text selected
          #    "selection"
          # 3. Never populate the search query
          #    "never"
          "seed_search_query_from_cursor" = "always";
          "use_smartcase_search" = false;

          # Inlay Hints
          inlay_hints = {
            enabled = true;
            show_type_hints = true;
            show_parameter_hints = true;
            # Corresponds to null/None LSP hint type value.
            show_other_hints = true;
            # If `true`, the current theme's `hint.background` color is applied.
            show_background = false;
            # Time to wait before requesting the hints. 0 disables debouncing.
            edit_debounce_ms = 700; # After editing the buffer.
            scroll_debounce_ms = 50; # After scrolling the buffer.
          };

          # Project Panel
          project_panel = {
            hide_gitignore = true;
            button = true;
            default_width = 240;
            dock = "left";
            auto_fold_dirs = false;
            folder_icons = true;
            file_icons = true;
            git_status = true;
            auto_reveal_entries = true;
            scrollbar = {
              show = "auto"; # auto, system, always, never
            };
            indent_size = 20;
            indent_guides = {
              show = "always";
            };
          };

          # Outline Panel
          outline_panel = {
            button = true;
            default_width = 300;
            dock = "left";
            auto_fold_dirs = true;
            folder_icons = true;
            file_icons = true;
            git_status = true;
            auto_reveal_entries = true;
            indent_size = 20;
            indent_guides = {
              show = "always";
            };
          };

          # Collaboration Panel
          collaboration_panel = {
            button = false;
            dock = "left";
            default_width = 240;
          };

          # Chat Panel
          chat_panel = {
            button = false;
            dock = "right";
            default_width = 240;
          };

          # Message Editor
          message_editor = {
            auto_replace_emoji_shortcode = true;
          };

          # Notification Panel
          notification_panel = {
            button = true;
            dock = "right";
            default_width = 380;
          };

          # Slash Commands
          slash_commands = {
            docs = {
              enabled = true;
            };
            project = {
              enabled = true;
            };
          };

          # When to automatically save edited buffers.
          # "off", "on_window_change", "on_focus_change", { "after_delay" = {"milliseconds" = 500} };
          autosave = "on_focus_change";
          ui_font_size = 24;
          buffer_font_size = 24;
          theme = {
            mode = "dark";
            light = "One Light";
            dark = "Snazzy Theme";
          };
          # ssh_connections = [
          #   {
          #     # host = "trex.satanic.link";
          #   }
          # ];

          # Control what info is collected by Zed.
          telemetry = {
            diagnostics = false;
            metrics = false;
          };

          # Add files or globs of files that will be excluded by Zed entirely:
          # they will be skipped during FS scan(s), file tree and file search
          # will lack the corresponding file entries.
          file_scan_exclusions = [
            "**/.git"
            "**/.svn"
            "**/.hg"
            "**/CVS"
            "**/.DS_Store"
            "**/Thumbs.db"
            "**/.classpath"
            "**/.settings"
            "**/.parquet"
          ];

  };
}
