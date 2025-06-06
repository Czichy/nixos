{
  localFlake,
  secretsPath,
  # inputs,
}: {
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    mkBefore
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkAgenixEnableOption
    attrNames
    filterAttrs
    flip
    mapAttrs'
    nameValuePair
    ;

  cfg = config.services.nginx;

  agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;

  monitoredUpstreams = filterAttrs (_: x: x.monitoring.enable) config.services.nginx.upstreams;
in {
  options.services.nginx = {
    agenix = {
      enable = mkAgenixEnableOption;
    };
    recommendedSetup = mkEnableOption "recommended setup parameters.";
    recommendedSecurityHeaders = mkEnableOption "additional security headers by default in each location block. Can be overwritten in each location with `recommendedSecurityHeaders`.";
    virtualHosts = mkOption {
      type = types.attrsOf (types.submodule {
        options.locations = mkOption {
          type = types.attrsOf (types.submodule (submod: {
            options = {
              recommendedSecurityHeaders = mkOption {
                type = types.bool;
                default = config.services.nginx.recommendedSecurityHeaders;
                description = "Whether to add additional security headers to this location.";
              };

              X-Frame-Options = mkOption {
                type = types.str;
                default = "DENY";
                description = "The value to use for X-Frame-Options";
              };
            };
            config = mkIf submod.config.recommendedSecurityHeaders {
              extraConfig = mkBefore ''
                # Enable HTTP Strict Transport Security (HSTS)
                add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

                # Minimize information leaked to other domains
                add_header Referrer-Policy "origin-when-cross-origin";

                add_header X-XSS-Protection "1; mode=block";
                add_header X-Frame-Options "${submod.config.X-Frame-Options}";
                add_header X-Content-Type-Options "nosniff";
              '';
            };
          }));
        };
      });
    };
    upstreams = mkOption {
      type = types.attrsOf (types.submodule {
        options.monitoring = {
          enable = mkOption {
            type = types.bool;
            description = "Whether to add a global monitoring entry for this upstream";
            default = false;
          };

          path = mkOption {
            type = types.str;
            description = "The path to query.";
            default = "";
          };

          expectedStatus = mkOption {
            type = types.int;
            default = 200;
            description = "The HTTP status code to expect.";
          };

          expectedBodyRegex = mkOption {
            type = types.nullOr types.str;
            description = "A regex pattern to expect in the body.";
            default = null;
          };

          useHttps = mkOption {
            type = types.bool;
            description = "Whether to use https to connect to this upstream when monitoring";
            default = false;
          };

          skipTlsVerification = mkOption {
            type = types.bool;
            description = "Skip tls verification when using https.";
            default = false;
          };
        };
      });
    };
  };

  config = mkIf (config.services.nginx.enable) (
    lib.mkMerge [
      # |----------------------------------------------------------------------| #
      (mkIf (config.services.nginx.recommendedSetup && agenixCheck) {
        age.secrets."dhparams.pem" = mkIf (config ? age) {
          file = secretsPath + "/nginx/dhparams.pem.age";
          mode = "440";
          group = "nginx";
        };

        networking.firewall.allowedTCPPorts = [80 443];

        # Sensible defaults for nginx
        services.nginx = {
          recommendedBrotliSettings = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
          recommendedTlsSettings = true;
          recommendedSecurityHeaders = true;

          # SSL config
          sslCiphers = "EECDH+AESGCM:EDH+AESGCM:!aNULL";
          sslDhparam = mkIf agenixCheck config.age.secrets."dhparams.pem".path;
          commonHttpConfig = ''
            log_format json_combined escape=json '{'
              '"time": $msec,'
              '"remote_addr":"$remote_addr",'
              '"status":$status,'
              '"method":"$request_method",'
              '"host":"$host",'
              '"uri":"$request_uri",'
              '"request_size":$request_length,'
              '"response_size":$body_bytes_sent,'
              '"response_time":$request_time,'
              '"referrer":"$http_referer",'
              '"user_agent":"$http_user_agent"'
            '}';
            error_log syslog:server=unix:/dev/log,nohostname;
            access_log syslog:server=unix:/dev/log,nohostname json_combined;
            ssl_ecdh_curve secp384r1;
          '';

          # Default host that rejects everything.
          # This is selected when no matching host is found for a request.
          virtualHosts.dummy = {
            default = true;
            rejectSSL = true;
            locations."/".extraConfig = ''
              deny all;
            '';
          };
        };
      })
      # |----------------------------------------------------------------------| #
      {
        globals.monitoring.http = flip mapAttrs' monitoredUpstreams (
          upstreamName: upstream: let
            schema =
              if upstream.monitoring.useHttps
              then "https"
              else "http";
          in
            nameValuePair "${config.node.name}-upstream-${upstreamName}" {
              url = map (server: "${schema}://${server}${upstream.monitoring.path}") (attrNames upstream.servers);
              network = "local-${config.node.name}";
              inherit
                (upstream.monitoring)
                expectedBodyRegex
                expectedStatus
                skipTlsVerification
                ;
            }
        );
      }
      # |----------------------------------------------------------------------| #
    ]
  );
}
