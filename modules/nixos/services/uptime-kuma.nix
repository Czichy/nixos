{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    mkImpermanenceEnableOption
    isModuleLoadedAndEnabled
    ;

  cfg = config.tensorfiles.services.uptime-kuma;
  uptime-port = "8095";
  uptime-host = "uptime.czichy.com";
  certloc = "/var/lib/acme/czichy.com";

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.uptime-kuma = with types; {
    enable = mkEnableOption ''uptime-kuma self-hosted monitoring tool'';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      globals.services.uptime-kuma.domain = uptime-host;
    }
    # |----------------------------------------------------------------------| #
    {
      services.uptime-kuma = {
        enable = true;
        settings = {PORT = toString uptime-port;};
      };

      users = {
        users.uptime-kuma = {
          isSystemUser = true;
          group = "uptime-kuma";
        };
        groups.uptime-kuma = {};
      };
    }
    # |----------------------------------------------------------------------| #
    (lib.mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [
          {
            directory = "/var/lib/private/uptime-kuma";
            user = "uptime-kuma";
            group = "uptime-kuma";
            mode = "0700";
          }
        ];
      };
    })
    # |----------------------------------------------------------------------| #
    {
      # TODO: configure private ip
      nodes.HL-4-PAZ-PROXY-01 = {
        services.caddy.virtualHosts."${uptime-host}".extraConfig = ''
            reverse_proxy 127.0.0.1:${uptime-port}

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
