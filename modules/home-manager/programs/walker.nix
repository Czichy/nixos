{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkPywalEnableOption;

  cfg = config.tensorfiles.hm.programs.walker;
in {
  options.tensorfiles.hm.programs.walker = with types; {
    enable = mkEnableOption ''
      TODO
    '';

    pywal = {
      enable = mkPywalEnableOption;
    };

    pkg = mkOption {
      type = package;
      default = pkgs.walker;
      description = ''
        Which package to use for the dmenu binaries. You can provide any
        custom derivation of your choice as long as the main binaries
        reside at

        - `$pkg/bin/dmenu`
        - `$pkg/bin/dmenu_run`
        - etc...
      '';
    };
    runAsService = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run Walker as a background service for faster startup";
    };
  };
  imports = [
    inputs.walker.homeManagerModules.default
  ];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.walker = {
        enable = true;
        package = cfg.pkg;

        inherit (cfg) runAsService;
        # Configuration options for Walker
        config = {
          search.placeholder = "Search...";
          ui = {
            fullscreen = false;
            centered = true; # Add this to center Walker on the screen
            icon_theme = "Adwaita"; # Explicit icon theme to avoid mismatches
            icon_size = 26; # Match the system theme size of 26px
          };
          as_window = false;
          list = {
            height = 800;
            width = 1000;
            center = true; # Add this to explicitly center the list
          };
          hotreload_theme = true;
          builtins.windows.weight = 100;
          builtins.clipboard = {
            prefix = ''"'';
            always_put_new_on_top = true;
          };
          activation_mode.disabled = true;
          ignore_mouse = true;
          websearch.prefix = "?";
          switcher.prefix = "/";
          # theme = "gruvbox";

          # Enable and configure Walker modules
          modules = {
            # Core modules
            applications = {
              enable = true;
              # Filter out desktop entries with empty exec lines
              filter = "true"; # Default filter
              fuzzy = true; # Enable fuzzy matching
              show_icons = true; # Show application icons
            };
            calculator.enable = true;
            runner.enable = true;
            clipboard = {
              enable = true;
              # Always put new clipboard entries at the top
              always_put_new_on_top = true;
            };

            # Web and search modules
            websearch = {
              enable = true;
              # Custom search engines
              entries = [
                {
                  name = "GitHub";
                  url = "https://github.com/search?q=%s";
                  prefix = "gh";
                }
                {
                  name = "NixOS Packages";
                  url = "https://search.nixos.org/packages?query=%s";
                  prefix = "nix";
                }
              ];
            };

            # System and window management
            windows.enable = true;
            switcher.enable = true;

            # Development tools
            ssh.enable = true;
            commands.enable = true;

            # Additional useful modules
            bookmarks.enable = true;
            translation = {
              enable = true;
              provider = "googlefree";
            };

            # AI module for Claude integration
            ai = {
              enable = true;
              # Comment out Anthropic integration until API key is fixed
              anthropic = {
                prompts = [
                  {
                    model = "claude-3-5-sonnet-20241022";
                    temperature = 1.0;
                    max_tokens = "1_000";
                    label = "Code Helper";
                    prompt = "You are a helpful coding assistant focused on helping with programming tasks. Keep your answers concise and practical.";
                  }
                  {
                    model = "claude-3-5-sonnet-20241022";
                    temperature = 0.7;
                    max_tokens = "1_000";
                    label = "NixOS Expert";
                    prompt = "You are a NixOS expert. Help the user with their NixOS configuration, modules, and package management questions.";
                  }
                ];
              };
            };

            # Custom commands for frequently used tools
            customCommands = {
              enable = true;
              commands = [
                {
                  name = "Rebuild NixOS";
                  cmd = "sudo nixos-rebuild switch --flake /home/${config.home.username}/.config/nixos#";
                  terminal = true;
                }
                {
                  name = "Edit Walker Config";
                  cmd = "nvim /home/${config.home.username}/.config/nixos/home/desktop/walker/default.nix";
                  terminal = true;
                }
              ];
            };
          };
        };
      };

      # Add auto-start for Hyprland if runAsService is enabled
      wayland.windowManager.hyprland.extraConfig = mkIf (cfg.runAsService && config.tensorfiles.hm.desktop.window-managers.niri.enable) ''
        exec-once=walker --gapplication-service
      '';

      # Add auto-start for Sway if runAsService is enabled
      programs.niri.settings.spawn-at-startup = mkIf (cfg.runAsService && config.tensorfiles.hm.desktop.window-managers.niri.enable) [
        {command = ["walker" "--gapplication-service"];}
      ];
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
