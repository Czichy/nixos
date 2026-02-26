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
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.services.ntfy-sh;
  ntfy-port = "8090";
  ntfy-host = "push.czichy.com";
  certloc = "/var/lib/acme/czichy.com";

  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;
in {
  options.tensorfiles.services.ntfy-sh = with types; {
    enable = mkEnableOption ''ntfy-sh notification server'';

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      globals.services.ntfy-sh.domain = ntfy-host;
      globals.monitoring.http.ntfy-sh = {
        url = "https://${ntfy-host}";
        expectedStatus = 404; # web-root=disable → 404 is expected
        network = "internet";
      };
    }
    # |----------------------------------------------------------------------| #
    {
      services.ntfy-sh = {
        enable = true;
        settings = {
          behind-proxy = true;
          listen-http = "127.0.0.1:${ntfy-port}";
          base-url = "https://${ntfy-host}";
          auth-file = "/var/lib/ntfy-sh/user.db";
          auth-default-access = "deny-all";
          upstream-base-url = "https://ntfy.sh";
          # https://github.com/binwiederhier/ntfy/issues/459
          web-root = "disable"; # Set to "app" to enable web UI
        };
      };

      users.users.ntfy-sh = {
        home = "/var/lib/ntfy-sh";
        # createHome = true;
      };
    }
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      age.secrets.ntfy-readonly-pass = {
        file = secretsPath + "/ntfy-sh/readonly-pass.age";
        owner = config.services.ntfy-sh.user;
      };
      age.secrets.ntfy-alert-pass = {
        file = secretsPath + "/ntfy-sh/alert-pass.age";
        owner = config.services.ntfy-sh.user;
      };
    })
    # |----------------------------------------------------------------------| #
    (mkIf agenixCheck {
      systemd.services.ntfy-sh.postStart = let
        ntfy = lib.getExe' config.services.ntfy-sh.package "ntfy";
        tokenFile = "/var/lib/ntfy-sh/healthchecks-token";
        script = pkgs.writeShellScript "ntfy-setup-users.sh" ''
          ${ntfy} access everyone '*' deny

          if ! ${ntfy} user list | grep -q 'user alert'; then
            NTFY_PASSWORD="$(cat ${config.age.secrets.ntfy-alert-pass.path})" \
              ${ntfy} user add alert
            ${ntfy} access alert '*' write-only
          fi

          if ! ${ntfy} user list | grep -q 'user readonly'; then
            NTFY_PASSWORD="$(cat ${config.age.secrets.ntfy-readonly-pass.path})" \
              ${ntfy} user add readonly
            ${ntfy} access readonly '*' read-only
          fi

          # Ensure a valid healthchecks token exists after every start/restart.
          # Remove all existing tokens labeled "healthchecks", then create a fresh one
          # and write it to a known path so healthchecks-sync-ntfy-token can pick it up.
          for OLD_TOKEN in $(${ntfy} token list 2>/dev/null \
              | ${pkgs.gnugrep}/bin/grep healthchecks \
              | ${pkgs.gnugrep}/bin/grep -oP 'tk_[a-z0-9]+'); do
            ${ntfy} token remove alert "$OLD_TOKEN" 2>/dev/null || true
          done
          TOKEN=$(${ntfy} token add --label healthchecks alert 2>&1 \
            | ${pkgs.gnugrep}/bin/grep -oP 'tk_[a-z0-9]+')
          echo "$TOKEN" > ${tokenFile}
          chmod 644 ${tokenFile}
          chown ntfy-sh:ntfy-sh ${tokenFile}
        '';
      in
        toString script;
    })
    # |----------------------------------------------------------------------| #
    {
      nodes.HL-4-PAZ-PROXY-01 = {
        services.caddy.virtualHosts."${ntfy-host}".extraConfig = ''
            reverse_proxy localhost:${ntfy-port}

            # tls ${certloc}/fullchain.pem ${certloc}/key.pem {
            #   protocols tls1.3
            # }
          import czichy_headers
        '';
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
