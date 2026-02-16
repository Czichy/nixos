{
  config,
  globals,
  secretsPath,
  hostName,
  pkgs,
  lib,
  ...
}:
# |----------------------------------------------------------------------| #
let
  domain = "home.czichy.com";
  certloc = "/var/lib/acme-sync/czichy.com";
  listenPort = 10001;

  # =====================================================================
  # AUTOMATIC SERVICE GENERATION FROM GLOBALS
  # =====================================================================

  # Filter enabled services from globals
  enabledServices = lib.filterAttrs (
    _: svc: (svc.homepage.enable or false) && (svc ? domain)
  ) globals.services;

  # Convert service to homepage format
  mkHomepageService =
    serviceName: svc:
    let
      displayName = svc.homepage.name or serviceName;
      serviceUrl = "https://${svc.domain}";
      baseEntry = {
        icon = svc.homepage.icon or "mdi-web";
        href = serviceUrl;
        description = svc.homepage.description or "${displayName} Service";
      };
      withAbbr =
        if (svc.homepage.abbr or null) != null then
          baseEntry // { abbr = svc.homepage.abbr; }
        else
          baseEntry;
      withPing =
        if (svc.homepage.ping or null) != null then withAbbr // { ping = svc.homepage.ping; } else withAbbr;
      # Add siteMonitor for availability checking (uses the service URL)
      withSiteMonitor =
        if (svc.homepage.siteMonitor or true) then withPing // { siteMonitor = serviceUrl; } else withPing;
      # Add widget configuration if defined
      withWidget =
        if (svc.homepage.widget or null) != null then
          withSiteMonitor // { widget = svc.homepage.widget; }
        else
          withSiteMonitor;
    in
    {
      ${displayName} = withWidget;
    };

  # Group by category
  servicesByCategory = lib.groupBy (svc: svc.homepage.category or "Services") (
    lib.mapAttrsToList (name: svc: svc // { _name = name; }) enabledServices
  );

  # Convert category to homepage format
  mkCategory =
    categoryName: services:
    let
      # Sort by priority (lower priority = higher on page)
      sortedServices = lib.sort (
        a: b: (a.homepage.priority or 100) < (b.homepage.priority or 100)
      ) services;
    in
    {
      ${categoryName} = map (svc: mkHomepageService svc._name svc) sortedServices;
    };

  # Generated services from globals
  generatedServices = lib.mapAttrsToList mkCategory servicesByCategory;
  # |----------------------------------------------------------------------| #
in
{
  microvm.mem = 512;
  microvm.vcpu = 1;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;

  networking.firewall = {
    allowedTCPPorts = [
      443
      10001
    ];
  };
  # |----------------------------------------------------------------------| #
  age.secrets.restic-node-red = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/node-red/restic-node-red.age";
    mode = "440";
  };

  age.secrets."rclone.conf" = {
    file = secretsPath + "/rclone/onedrive_nas/rclone.conf.age";
    mode = "440";
  };

  age.secrets.ntfy-alert-pass = {
    file = secretsPath + "/ntfy-sh/alert-pass.age";
    mode = "440";
  };

  age.secrets.node-red-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };

  # Homepage Widget Secrets
  age.secrets.homepage-env = {
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-03/guests/homepage/homepage-env.age";
    mode = "440";
  };

  # |----------------------------------------------------------------------| #
  # Der innere Caddy (HL-1-MRZ-HOST-02-caddy) muss nun ein eigenes TLS-Zertifikat bereitstellen,
  # damit der äußere Caddy eine sichere Verbindung aufbauen kann.
  # Der innere Caddy muss auch seine eigene reverse_proxy-Verbindung zum
  # Vaultwarden-Server über HTTPS herstellen.
  nodes.HL-1-MRZ-HOST-02-caddy = {
    services.caddy = {
      virtualHosts."${domain}".extraConfig = ''
        reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-HOME-01".ipv4}:${toString listenPort}
        tls ${certloc}/fullchain.pem ${certloc}/key.pem {
           protocols tls1.3
        }
        import czichy_headers
      '';
    };
  };
  # |----------------------------------------------------------------------| #

  # Icons :
  # - https://selfh.st/icons/ (sh-xx)
  # - https://simpleicons.org/ (si-xx)
  # - https://pictogrammers.com/library/mdi/ (mdi-xx)
  # - https://github.com/homarr-labs/dashboard-icons
  services.homepage-dashboard = {
    enable = true;
    listenPort = listenPort;
    allowedHosts = "${domain},10.15.40.37:10001";

    settings = {
      title = "Czichy Homelab";
      description = "Homelab Dashboard - Alle Services auf einen Blick";
      hideVersion = true;
    };

    widgets = [
      {
        openmeteo = {
          label = "Idstein";
          latitude = 50.248329;
          longitude = 8.256039;
          units = "metric";
          cache = 5;
        };
      }
      {
        resources = {
          cpu = true;
          disk = "/";
          memory = true;
        };
      }

      {
        search = {
          provider = "google";
          focus = true;
          showSearchSuggestions = true;
          target = "_self";
        };
      }
    ];

    # Automatically generated services from globals
    # Services appear here when they have `homepage.enable = true` in their globals.services definition
    services = generatedServices;

    # Bookmarks section (empty - all services come from globals.services)
    bookmarks = [ ];
  };

  # Inject environment secrets for widgets (HOMEPAGE_VAR_*)
  # The homepage service reads these from environment variables
  systemd.services.homepage-dashboard.serviceConfig.EnvironmentFile =
    lib.mkForce config.age.secrets.homepage-env.path;
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/var/lib/node-red";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #
}
