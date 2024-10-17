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
        createHome = true;
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
        '';
      in
        toString script;
    })
    # |----------------------------------------------------------------------| #
    {
      nodes.HL-4-PAZ-PROXY-01 = {
        services.caddy.virtualHosts."${ntfy-host}".extraConfig = ''
            reverse_proxy https://127.0.0.1:${ntfy-port}

            tls ${certloc}/cert.pem ${certloc}/key.pem {
              protocols tls1.3
            }
          import czichy_headers
        '';
      };
    }
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
