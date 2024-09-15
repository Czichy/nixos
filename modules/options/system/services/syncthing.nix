{
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (lib) mkAgenixEnableOption;
  cfg = config.modules.system.services.syncthing;
in {
  options.modules.system.services.syncthing = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the networkmanager service.
    '';

    dataDir = mkOption {
      type = types.path;
      default = "/home/${cfg.user}";
      example = "/home/yourUser";
      description = ''
        The path where synchronised directories will exist.
      '';
    };
    configDir = mkOption {
      type = types.path;
      default = "/home/${cfg.user}/.config/syncthing";
      example = "/home/yourUser";
      description = ''
        The directory containing the database and logs.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "czichy"; # defaultUser;
      example = "yourUser";
      description = ''
        The user to run Syncthing as.
        By default, a user named `${defaultUser}` will be created whose home
        directory is [dataDir](#opt-services.syncthing.dataDir).
      '';
    };

    isServer = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether the host is Server
      '';
    };
    port = mkOption {
      type = types.port;
      default = 8384;
      description = "The port to connect to.";
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
  };
}
