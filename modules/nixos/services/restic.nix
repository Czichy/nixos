{localFlake}: {
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
      ${pkgs.curl}/bin/curl -u $NTFY_USER:$NTFY_PASS \
      -H 'Title: Backup (${site}) on ${host} failed!' \
      -H 'Tags: backup,restic,${host},${site}' \
      -d "Restic (${site}) backup error on ${host}!" 'https://push.pablo.tools/pinpox_backups'
    else
      ${pkgs.curl}/bin/curl -u $NTFY_USER:$NTFY_PASS \
      -H 'Title: Backup (${site}) on ${host} successful!' \
      -H 'Tags: backup,restic,${host},${site}' \
      -d "Restic (${site}) backup success on ${host}!" 'https://push.pablo.tools/pinpox_backups'
    fi
  '';
in {
  options.tensorfiles.services.restic = with types; {
    enable = mkEnableOption ''ntfy-sh notification server'';
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
