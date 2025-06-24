{localFlake}: {
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkAgenixEnableOption;
  inherit (config.home.sessionVariables) TERMINAL BROWSER EXPLORER; # EDITOR

  ibkr = {
    user = config.age.secrets."${config.tensorfiles.hm.programs.ib-tws.userSecretsPath}".path;
    password = config.age.secrets."${config.tensorfiles.hm.programs.ib-tws.passwordSecretsPath}".path;
  };

  cfg = config.tensorfiles.hm.services.wayland.window-managers.niri;
  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;

  pointer = config.home.pointerCursor;
  makeCommand = command: {
    command = [command];
  };
in {
  options.tensorfiles.hm.services.wayland.window-managers.niri = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the niriwindow manager.
    '';

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  imports = [inputs.niri.homeModules.niri ./settings.nix ./binds.nix ./rules.nix];

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home = {
        packages = with pkgs; [
          grimblast
          swaybg
          slurp
          swappy
          jaq
          xorg.xprop
          wdisplays
        ];
      };

      programs.niri = {
        enable = true;
        package = pkgs.niri;
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
