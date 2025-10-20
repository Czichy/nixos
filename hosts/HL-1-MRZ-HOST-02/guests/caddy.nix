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
  networking.hostName = "HL-3-DMZ-PROXY-01";
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
    '';
    virtualHosts."localhost".extraConfig = ''
      respond "OK"
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
    '';
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

  # topology.self.services.caddy.info = "https://" + caddyLocalDomain;

  # topology.self.connections.dmz = mkConnection "HL-3-MRZ-FW-01" "dmz";
  system.stateVersion = "24.05";
}
