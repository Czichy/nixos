{
  config,
  globals,
  nodes,
  ...
}: let
  linkwardenDomain = "links.${globals.domains.me}";
in {
  microvm.mem = 1024 * 4;
  microvm.vcpu = 8;

  globals.services.linkwarden = {
    domain = linkwardenDomain;
    homepage = {
      enable = true;
      name = "Linkwarden";
      icon = "sh-linkwarden";
      description = "Bookmark Manager & Archiver";
      category = "Documents & Notes";
      priority = 15;
    };
  };
  globals.monitoring.http.linkwarden = {
    url = "https://${linkwardenDomain}";
    expectedBodyRegex = "<title>Linkwarden";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/linkwarden";
      user = "linkwarden";
      group = "linkwarden";
      mode = "0750";
    }
  ];

  services.linkwarden = {
    enable = true;
    host = "0.0.0.0";
    database.createLocally = true;
    enableRegistration = false;

    secretFiles.NEXTAUTH_SECRET = config.age.secrets.linkwarden-nextauth-secret.path;
    secretFiles.AUTHENTIK_CLIENT_SECRET = config.age.secrets.linkwarden-oauth2-client-secret.path;

    # NOTE: Well yes - it does not support generic OIDC so we piggyback on the AUTHENTIK provider
    environment = rec {
      RE_ARCHIVE_LIMIT = "0";
      NEXTAUTH_URL = "https://${linkwardenDomain}/api/v1/auth";
      NEXT_PUBLIC_CREDENTIALS_ENABLED = "false"; # disables username / pass authentication
      NEXT_PUBLIC_AUTHENTIK_ENABLED = "true";
      NEXT_PUBLIC_MAX_FILE_BUFFER = "100"; # in MB
      AUTHENTIK_ISSUER = "https://${globals.services.kanidm.domain}/oauth2/openid/${AUTHENTIK_CLIENT_ID}";
      AUTHENTIK_CLIENT_ID = "linkwarden";
      AUTHENTIK_CUSTOM_NAME = "Kanidm (SSO)";
    };
  };

  backups.storageBoxes.dusk = {
    subuser = "linkwarden";
    paths = ["/var/lib/linkwarden"];
    withPostgres = true;
  };
}
