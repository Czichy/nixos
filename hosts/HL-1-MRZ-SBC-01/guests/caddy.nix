{
  config,
  lib,
  # globals,
  secretsPath,
  ...
}:
with builtins; let
  inherit
    (lib)
    genAttrs
    ;
  caddyLocalDomain = "caddy.czichy.com";

  acme-cfg = config.tensorfiles.services.networking.acme;
  caddyMetricsPort = 2019;
in {
  # |----------------------------------------------------------------------| #
  networking.firewall.allowedTCPPorts = [
    80 # Caddy
    443 # Caddy
    caddyMetricsPort
  ];
  # |----------------------------------------------------------------------| #

  services.caddy = {
    enable = true;
    email = "christian@czichy.com";
    # On the back, the trusted_proxies global option is used to tell Caddy to trust the front instance as a proxy.
    # This ensures the real client IP is preserved.
    globalConfig = ''
      servers {
      	trusted_proxies static private_ranges
      }

           # acme_dns cloudflare {
           # 	zone_token {env.CF_ZONE_API_TOKEN_FILE}
           # 	api_token {env.CF_DNS_API_TOKEN_FILE}
           # }
    '';
    virtualHosts."localhost".extraConfig = ''
      respond "OK"
    '';

    # package = pkgs.callPackage ./custom-caddy.nix {
    #   plugins = [
    #     # "github.com/mholt/caddy-l4"
    #     # "github.com/caddyserver/caddy/v2/modules/standard"
    #     # "github.com/hslatman/caddy-crowdsec-bouncer/http@main"
    #     # "github.com/hslatman/caddy-crowdsec-bouncer/layer4@main"
    #     "github.com/caddy-dns/cloudflare"
    #   ];
    # };
  };

  # |----------------------------------------------------------------------| #

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
  # |----------------------------------------------------------------------| #

  age.secrets.acme-cloudflare-dns-token = {
    file = secretsPath + "/cloudflare/acme-cloudflare-dns-token.age";
    mode = "440";
    group = "acme";
  };

  age.secrets.acme-cloudflare-zone-token = {
    file = secretsPath + "/cloudflare/acme-cloudflare-dns-token.age";
    mode = "440";
    group = "acme";
  };

  users.groups.acme.members = ["caddy"];
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "christian@czichy.com";
      credentialFiles = {
        CF_DNS_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-dns-token.path;
        CF_ZONE_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-zone-token.path;
      };
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      reloadServices = ["caddy"];
    };
    certs = genAttrs acme-cfg.wildcardDomains (domain: {
      extraDomainNames = ["*.${domain}"];
    });
  };

  # |----------------------------------------------------------------------| #

  topology.self.services.nginx.info = "https://" + caddyLocalDomain;
  networking.hostName = "HL-1-MRZ-SBC-01-caddy";
  system.stateVersion = "24.05";
}