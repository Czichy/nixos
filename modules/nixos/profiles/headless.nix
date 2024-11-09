{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtProfileLevel;

  cfg = config.tensorfiles.profiles.headless;
  _ = mkOverrideAtProfileLevel;
in {
  options.tensorfiles.profiles.headless = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the headless system profile.

      **Headless layer** builds on top of the minimal layer and adds other
      server-like functionality like simple shells, basic networking for remote
      access and simple editors.
    '';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      tensorfiles = {
        profiles.minimal.enable = _ true;

        security.agenix.enable = _ true;

        # services.networking.networkmanager.enable = _ true;
        services.networking.ssh.enable = _ true;
        services.networking.ssh.genHostKey.enable = _ true;

        system.users = {
          enable = _ true;
          usersSettings = {
            "root" = {};
          };
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
