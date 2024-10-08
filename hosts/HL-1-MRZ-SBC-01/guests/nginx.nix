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
  #   isModuleLoadedAndEnabled
  #   mkImpermanenceEnableOption
  #   mkAgenixEnableOption
  #   ;
  nginxLocalDomain = "nginx.czichy.com";

  acme-cfg = config.tensorfiles.services.networking.acme;
in {
  # |----------------------------------------------------------------------| #
  services.nginx = {
    enable = true;
    recommendedSetup = true;
  };

  # |----------------------------------------------------------------------| #
  age.secrets."dhparams.pem" = {
    file = secretsPath + "/nginx/dhparams.pem.age";
    mode = "440";
    group = "nginx";
  };

  # |----------------------------------------------------------------------| #
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
    sslDhparam = config.age.secrets."dhparams.pem".path;
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
  # |----------------------------------------------------------------------| #
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

  users.groups.acme.members = ["nginx"];
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
      reloadServices = ["nginx"];
    };
    certs = genAttrs acme-cfg.wildcardDomains (domain: {
      extraDomainNames = ["*.${domain}"];
    });
  };

  # |----------------------------------------------------------------------| #

  topology.self.services.nginx.info = "https://" + nginxLocalDomain;
  networking.hostName = "HL-1-MRZ-SBC-01-nginx";
  system.stateVersion = "24.05";
}
