{
  config,
  inputs,
  ...
}: let
  inherit (inputs.self) secretsPath;
  # inherit (config.repo.secrets.local) acme;
in {
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
    # inherit (acme) certs wildcardDomains;
  };
}
