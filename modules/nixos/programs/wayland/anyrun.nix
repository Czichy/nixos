{
  localFlake,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.programs.wayland.anyrun;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.programs.wayland.anyrun = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the anyrun app launcher

      https://github.com/Kirottu/anyrun
    '';

    # home = {
    #   enable = mkHomeEnableOption;

    #   settings = mkHomeSettingsOption (_user: {});
    # };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    (mkIf cfg.home.enable {
      home-manager.users = genAttrs (attrNames cfg.home.settings) (
        _user: let
          userTerminal = getUserTerminal {
            inherit _user;
            cfg = config;
          };
        in {
          # Since this module is completely isolated and single purpose
          # (meaning that the only possible place to import it from tensorfiles
          # is here) we can leave the import call here
          imports = [inputs.anyrun.homeManagerModules.default];

          programs.anyrun = {
            enable = _ true;

            config = {
              plugins = with inputs.anyrun.packages.${pkgs.system}; [
                applications
                randr
                rink
                shell
                websearch
                kidex
                #symbols
              ];

              width.fraction = _ 0.3;
              y.absolute = _ 15;
              hidePluginInfo = _ true;
              closeOnClick = _ true;
              maxEntries = _ 4;
            };

            extraConfigFiles."applications.ron".text = mkBefore ''
              Config(
                terminal: Some("${userTerminal}")
              )
            '';

            extraCss = mkBefore ''
              * {
                all: unset;
                font-size: 1.3rem;
              }

              #window,
              #match,
              #entry,
              #plugin,
              #main {
                background: transparent;
              }

              #match.activatable {
                border-radius: 16px;
                padding: 0.3rem 0.9rem;
                margin-top: 0.01rem;
              }
              #match.activatable:first-child {
                margin-top: 0.7rem;
              }
              #match.activatable:last-child {
                margin-bottom: 0.6rem;
              }

              #plugin:hover #match.activatable {
                border-radius: 10px;
                padding: 0.3rem;
                margin-top: 0.01rem;
                margin-bottom: 0;
              }

              #match:selected,
              #match:hover,
              #plugin:hover {
                background: rgba(255, 255, 255, 0.1);
              }

              #entry {
                background: rgba(255, 255, 255, 0.05);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 16px;
                margin: 0.5rem;
                padding: 0.3rem 1rem;
              }

              list > #plugin {
                border-radius: 16px;
                margin: 0 0.3rem;
              }
              list > #plugin:first-child {
                margin-top: 0.3rem;
              }
              list > #plugin:last-child {
                margin-bottom: 0.3rem;
              }
              list > #plugin:hover {
                padding: 0.6rem;
              }

              box#main {
                background: rgba(0, 0, 0, 0.5);
                box-shadow:
                  inset 0 0 0 1px rgba(255, 255, 255, 0.1),
                  0 0 0 1px rgba(0, 0, 0, 0.5);
                border-radius: 24px;
                padding: 0.3rem;
              }
            '';
          };
        }
      );
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
