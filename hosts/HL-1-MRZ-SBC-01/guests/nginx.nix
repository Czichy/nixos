{
  config,
  globals,
  secretsPath,
  ...
}: let
  nginxLocalDomain = "nginx.czichy.com";
in {
  # |----------------------------------------------------------------------| #
  services.nginx = {
    enable = true;
    recommendedSetup = true;
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
    certs.extraDomainNames = ["*.${globals.domains.local}"];
  };

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [53 80 443 3000];
    allowedUDPPorts = [53];
  };

  topology.self.services.nginx.info = "https://" + nginxLocalDomain;
  systemd.network.enable = true;
  networking.hostName = "HL-1-MRZ-SBC-01-nginx";
  system.stateVersion = "24.05";
}
