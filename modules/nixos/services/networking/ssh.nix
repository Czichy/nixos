{localFlake}: {
  config,
  lib,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) mkOverrideAtModuleLevel;

  cfg = config.tensorfiles.services.networking.ssh;
  _ = mkOverrideAtModuleLevel;
in {
  options.tensorfiles.services.networking.ssh = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles everything related to ssh,
      that is remote access, messagess, ssh-agents and ssh-keys with the
      openssh backend.
    '';

    genHostKey = {
      enable = mkEnableOption ''
        Enables autogenerating per-host based keys. Apart from certain additional
        checks this works mostly as a passthrough to
        `openssh.authorizedKeys.keys`, for more info refer to the documentation
        of said option.
      '';

      hostKey = mkOption {
        type = attrs;
        default = {
          type = "ed25519";
          path = "/persist/etc/ssh/ssh_host_ed25519_key";
        };
        description = ''
          TODO
        '';
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      programs.ssh = {
        startAgent = _ true;
        extraConfig = mkBefore ''
          # a private key that is used during authentication will be added to ssh-agent if it is running
          AddKeysToAgent yes
        '';
      };
      services.openssh = {
        enable = _ true;
        banner = mkBefore ''
          =====================================================================
          Welcome, you should note that this host is completely
          built/rebuilt/managed using the nix ecosystem and any manual changes
          will most probably be lost. If you are unsure about what you are
          doing, please refer to the tensorfiles documentation.

          Thank you and happy computing.
          =====================================================================
        '';
        settings = {
          PermitRootLogin = _ "yes";
          PasswordAuthentication = _ false;
          StrictModes = _ true;
          KbdInteractiveAuthentication = _ false;
        };
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf cfg.genHostKey.enable {services.openssh.hostKeys = [cfg.genHostKey.hostKey];})
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
