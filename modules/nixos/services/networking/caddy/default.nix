{
  localFlake,
  secretsPath,
}: {
  catalog,
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
      nix.settings.sandbox = false;
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
          EnvironmentFile = [
            config.age.secrets.caddy-cloudflare-token.path
          ];
          TimeoutStartSec = "5m";
        };
      };
    }
    # |----------------------------------------------------------------------| #
  ]);
}
