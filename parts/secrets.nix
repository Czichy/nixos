{
  self,
  inputs,
  ...
}: let
  localFlake = self;
in {
  flake.secretsPath = "${inputs.private}";
  flake.nixosModules.security_agenix = {
    config,
    lib,
    pkgs,
    system,
    ...
  }:
    with builtins;
    with lib; let
      cfg = config.tensorfiles.security.agenix;
    in {
      options.tensorfiles.security.agenix = with types; {
        enable = mkEnableOption ''
          Enables NixOS module that sets up & configures the agenix secrets
          backend.

          References
          - https://github.com/ryantm/agenix
          - https://nixos.wiki/wiki/Agenix
        '';
      };

      imports = with inputs; [agenix.nixosModules.default];

      config = mkIf cfg.enable {
        environment.systemPackages = [
          inputs.agenix.packages.${system}.default
          pkgs.age
        ];

        age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      };

      meta.maintainers = with localFlake.lib.maintainers; [czichy];
    };

  flake.homeModules.security_agenix = {
    config,
    lib,
    ...
  }:
    with builtins;
    with lib; let
      cfg = config.tensorfiles.hm.security.agenix;
    in {
      options.tensorfiles.hm.security.agenix = with types; {
        enable = mkEnableOption ''
          Enable Home Manager module that sets up & configures the agenix
          secrets backend.

          References
          - https://github.com/ryantm/agenix
          - https://nixos.wiki/wiki/Agenix
        '';

        secretsPath = lib.mkOption {
          type = path;
          default = "${inputs.private}";
          #default = ./secrets;
          description = "Path to the actual secrets directory";
        };
      };

      imports = with inputs; [
        # agenix.homeManagerModules.default
        agenix.homeManagerModules.age
      ];

      config = mkIf cfg.enable {
        age.identityPaths = [
          "${config.home.homeDirectory}/.ssh/id_ed25519"
          "${config.home.homeDirectory}/.ssh/czichy_desktop_ed25519"
        ];
      };

      meta.maintainers = with localFlake.lib.maintainers; [czichy];
    };
  # };
}
