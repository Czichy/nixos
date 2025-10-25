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
    ;

  cfg = config.tensorfiles.hm.programs.editors.zed;
  _ = mkOverrideAtHmModuleLevel;
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
        extensions = [
          "nix"
          "xy-zed" # a gorgeous dark theme
          "toml"
        ];
        userSettings = {
          helix_mode = true;
          vim = {
            default_mode = "helix_normal";
          };
          features = {
            copilot = true;
            inline_completion_provider = "copilot";
          };
          # Language Models.
          language_models = {
            openai = {
              version = 1;
              available_models = [
                {
                  name = "gpt-5";
                  display_name = "gpt-5 high";
                  reasoning_effort = "high";
                  max_tokens = 272000;
                  max_completion_tokens = 20000;
                }
                {
                  name = "gpt-4o-2024-08-06";
                  display_name = "GPT 4o Summer 2024";
                  max_tokens = 128000;
                }
              ];
            };
            anthropic = {
              version = 1;
              available_models = [];
            };
            copilot_chat = {available_models = [];};
            google = {
              available_models = [
                {
                  name = "gemini-2.5-pro-exp-03-25";
                  display_name = "Gemini 2.5 Pro Exp";
                  max_tokens = 1000000;
                }
              ];
            };
            deepseek = {
              api_url = "https://api.deepseek.com";
              available_models = [
                {
                  name = "deepseek-chat";
                  display_name = "DeepSeek Chat";
                  max_tokens = 64000;
                }
                {
                  name = "deepseek-reasoner";
                  display_name = "DeepSeek Reasoner";
                  max_tokens = 64000;
                  max_output_tokens = 4096;
                }
              ];
            };
            zed.dev = {available_models = [];};
            ollama = {
              low_speed_timeout_in_seconds = 120;
              available_models = [
                {
                  provider = "ollama";
                  name = "devstral:24b";
                  display_name = "Mistral Devstral - 24B";
                  max_tokens = 131072;
                  supports_tools = true;
                }
                {
                  provider = "ollama";
                  name = "qwen3:30b-a3b";
                  display_name = "Qwen 3 - 30B";
                  max_tokens = 131072;
                  supports_tools = true;
                }
                {
                  provider = "ollama";
                  name = "qwen3:4b";
                  display_name = "Qwen 3 - 4B";
                  max_tokens = 32768;
                  supports_tools = true;
                }
              ];
            };
          };

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
          "inlay_hints" = {
            "enabled" = true;
            "show_type_hints" = true;
            "show_parameter_hints" = true;
            # Corresponds to null/None LSP hint type value.
            "show_other_hints" = true;
            # If `true`, the current theme's `hint.background` color is applied.
            "show_background" = false;
            # Time to wait before requesting the hints. 0 disables debouncing.
            "edit_debounce_ms" = 700; # After editing the buffer.
            "scroll_debounce_ms" = 50; # After scrolling the buffer.
          };

          # Project Panel
          "project_panel" = {
            "button" = true;
            "default_width" = 240;
            "dock" = "left";
            "auto_fold_dirs" = false;
            "folder_icons" = true;
            "file_icons" = true;
            "git_status" = true;
            "auto_reveal_entries" = true;
            "scrollbar" = {
              "show" = "auto"; # "auto", "system", "always", "never"
            };
            "indent_size" = 20;
            "indent_guides" = {
              "show" = "always";
            };
          };

          # Outline Panel
          "outline_panel" = {
            "button" = true;
            "default_width" = 300;
            "dock" = "left";
            "auto_fold_dirs" = true;
            "folder_icons" = true;
            "file_icons" = true;
            "git_status" = true;
            "auto_reveal_entries" = true;
            "indent_size" = 20;
            "indent_guides" = {
              "show" = "always";
            };
          };

          # Collaboration Panel
          "collaboration_panel" = {
            "button" = true;
            "dock" = "left";
            "default_width" = 240;
          };

          # Chat Panel
          "chat_panel" = {
            "button" = true;
            "dock" = "right";
            "default_width" = 240;
          };

          # Message Editor
          "message_editor" = {
            "auto_replace_emoji_shortcode" = true;
          };

          # Notification Panel
          "notification_panel" = {
            "button" = true;
            "dock" = "right";
            "default_width" = 380;
          };

          "assistant" = {
            "version" = "2";
            "enabled" = true;
            "button" = true;
            "dock" = "right";
            "default_width" = 640;
            "default_height" = 320;
            "default_model" = {
              "provider" = "zed.dev";
              "model" = "claude-3-5-sonnet-latest";
            };
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

          # Automatically Installed Extensions
          auto_install_extensions = {
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
          # vim_mode = true;
          ui_font_size = 24;
          buffer_font_size = 24;
          theme = {
            mode = "dark";
            light = "One Light";
            dark = "One Dark";
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

        userKeymaps = import ./keymaps.nix;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
