{
  localFlake,
  secretsPath,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  cfg = config.tensorfiles.services.restic;
  script-post = host: site: ''
    if [ $EXIT_STATUS -ne 0 ]; then
      ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
      -H 'Title: Backup (${site}) on ${host} failed!' \
      -H 'Tags: backup,restic,${host},${site}' \
      -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
    else
      ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
      -H 'Title: Backup (${site}) on ${host} successful!' \
      -H 'Tags: backup,restic,${host},${site}' \
      -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'
      &&   ${pkgs.curl}/bin/curl   https://uptime.czichy.com/api/push/oPz4MJsFPX?status=up&msg=OK&ping=
    fi
  '';
in {
  options.tensorfiles.services.restic = with types; {
    enable = mkEnableOption ''Enable Restic Backup'';
  };
  options.services.restic.backups = lib.mkOption {
    description = ''
      Periodic backups to create with Restic.
    '';
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        passwordFile = lib.mkOption {
          type = lib.types.str;
          description = ''
            Read the repository password from a file.
          '';
          example = "/etc/nixos/restic-password";
        };
      };
    }));
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
