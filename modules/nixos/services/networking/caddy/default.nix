{
  localFlake,
  secretsPath,
}: {
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  inherit
    (localFlake.lib)
    # isModuleLoadedAndEnabled
    mkAgenixEnableOption
    ;

  cfg = config.tensorfiles.services.networking.caddy;

  # agenixCheck = (isModuleLoadedAndEnabled config "tensorfiles.security.agenix") && cfg.agenix.enable;

  caddyMetricsPort = 2019;
in {
  options.tensorfiles.services.networking.caddy = with types; {
    enable = mkEnableOption ''
      Deploy reverse proxy Caddy
    '';

    agenix = {
      enable = mkAgenixEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    # Allow network access when building
    # https://mdleom.com/blog/2021/12/27/caddy-plugins-nixos/#xcaddy
    {
      # nix.settings.sandbox = false;
    }
    # |----------------------------------------------------------------------| #
    {
      networking.firewall.allowedTCPPorts = [
        80 # Caddy
        443 # Caddy
        caddyMetricsPort
      ];
    }
    # |----------------------------------------------------------------------| #
    # (mkIf agenixCheck {
    #   age.secrets.caddy-cloudflare-token = {
    #     file = secretsPath + "/cloudflare/caddy-cloudflare-token.age";
    #     mode = "440";
    #     group = "caddy";
    #   };
    # })
    # |----------------------------------------------------------------------| #
    {
      services.caddy = {
        enable = true;
        email = "christian@czichy.com";
        # On the back, the trusted_proxies global option is used to tell Caddy to trust the front instance as a proxy.
        # This ensures the real client IP is preserved.
        logFormat = ''
            output file /var/log/caddy/access.log {
          	roll_size 10mb
          	roll_keep 5
          	roll_keep_for 168h
          }
        '';
        globalConfig = ''
          servers {
          	trusted_proxies static private_ranges
          	trusted_proxies static 10.46.0.0/24
          }

               # acme_dns cloudflare {
               # 	zone_token {env.CF_ZONE_API_TOKEN_FILE}
               # 	api_token {env.CF_DNS_API_TOKEN_FILE}
               # }
        '';
        extraConfig = ''
          (czichy_headers) {
            	header {
            		Permissions-Policy interest-cohort=()
            		Strict-Transport-Security "max-age=31536000; includeSubdomains"
            		X-XSS-Protection "1; mode=block"
            		X-Content-Type-Options "nosniff"
            		X-Robots-Tag noindex, nofollow
            		Referrer-Policy "same-origin"
            		Content-Security-Policy "frame-ancestors czichy.com *.czichy.com "
            		-Server
            		Permissions-Policy "geolocation=(self czichy.com *.czichy.com ), microphone=()"
            	}
            }
            # (personal_headers) {
            # 	header {
            # 		Permissions-Policy interest-cohort=()
            # 		Strict-Transport-Security "max-age=31536000; includeSubdomains"
            # 		X-XSS-Protection "1; mode=block"
            # 		X-Content-Type-Options "nosniff"
            # 		X-Robots-Tag noindex, nofollow
            # 		Referrer-Policy "same-origin"
            # 		Content-Security-Policy "frame-ancestors {{ secret_personal_url }} *.{{ secret_personal_url }}"
            # 		-Server
            # 		Permissions-Policy "geolocation=(self {{ secret_personal_url }} *.{{ secret_personal_url }}), microphone=()"
            # 	}
            # }
        '';
        # virtualHosts."localhost".extraConfig = ''
        #   respond "OK"
        # '';

        # package = pkgs.callPackage ./custom-caddy.nix {
        #   plugins = [
        #     # "github.com/mholt/caddy-l4"
        #     # "github.com/caddyserver/caddy/v2/modules/standard"
        #     # "github.com/hslatman/caddy-crowdsec-bouncer/http@main"
        #     # "github.com/hslatman/caddy-crowdsec-bouncer/layer4@main"
        #     "github.com/caddy-dns/cloudflare"
        #   ];
        #   globalConfig = ''
        #     acme_dns cloudflare {
        #     	zone_token {env.CF_ZONE_API_TOKEN_FILE}
        #     	api_token {env.CF_DNS_API_TOKEN_FILE}
        #     }
        #   '';
        # };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      systemd.services.caddy = {
        serviceConfig = {
          # Required to use ports < 1024
          AmbientCapabilities = "cap_net_bind_service";
          CapabilityBoundingSet = "cap_net_bind_service";
          # Allow Caddy to read Cloudflare API key for DNS validation
          # EnvironmentFile = [
          #   config.age.secrets.caddy-cloudflare-token.path
          # ];
          TimeoutStartSec = "5m";
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);
}
