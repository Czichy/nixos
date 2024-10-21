{
  config,
  lib,
  ...
}:
with lib;
with builtins; let
  hasAnyAttr = flip (attrset: any (flip hasAttr attrset));

  # script-post = host: site: ''
  #   if [ $EXIT_STATUS -ne 0 ]; then
  #     ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
  #     -H 'Title: Backup (${site}) on ${host} failed!' \
  #     -H 'Tags: backup,restic,${host},${site}' \
  #     -d "Restic (${site}) backup error on ${host}!" '${ntfy_url}'
  #   else
  #     ${pkgs.curl}/bin/curl -u alert:${ntfy_pass} \
  #     -H 'Title: Backup (${site}) on ${host} successful!' \
  #     -H 'Tags: backup,restic,${host},${site}' \
  #     -d "Restic (${site}) backup success on ${host}!" '${ntfy_url}'

  #    ${pkgs.curl}/bin/curl https://uptime.czichy.com/api/push/AfaxuEEWaI?status=up&msg=OK&ping=
  #   fi
  # '';

  resticConfig = args @ {
    name,
    paths ? [],
    ignorePatterns ? [],
    extraBackupArgs ? [],
    extraPruneOpts ? [],
    ...
  }:
    assert !hasAnyAttr [
      "initialize"
      "repository"
      "s3CredentialsFile"
      "passwordFile"
      "pruneOpts"
    ]
    args;
    assert (args ? paths);
      {
        initialize = true;
        repository = "b2:felschr-backups:/${name}";
        environmentFile = config.age.secrets.restic-b2.path;
        passwordFile = config.age.secrets.restic-password.path;
        timerConfig.OnCalendar = "daily";
        inherit paths;
        extraBackupArgs = let
          ignoreFile = builtins.toFile "ignore" (foldl (a: b: a + "\n" + b) "" ignorePatterns);
        in
          ["--exclude-file=${ignoreFile}"] ++ extraBackupArgs;
        pruneOpts =
          [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 3"
            "--keep-yearly 1"
            # reduce download bandwidth
            "--max-unused 10%"
            "--repack-cacheable-only"
          ]
          ++ extraPruneOpts;
      }
      // (removeAttrs args [
        "name"
        "paths"
        "ignorePatterns"
        "extraBackupArgs"
        "extraPruneOpts"
      ]);
in {
  inherit resticConfig;
}
