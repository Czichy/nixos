# Pinned tabs for the Smart Home space.
# workspace UUID must match the space id defined in spaces/smart-home.nix.
# Services are discovered from the project's Caddy/guest configurations.
_inputs: let
  # UUID of the "Smart Home" space (must match spaces/smart-home.nix)
  smartHomeWorkspace = "a1b2c3d4-0002-4000-8000-000000000002";
  # Container id for Smart Home (must match containers.nix)
  smartHomeContainer = 2;
in {
  "Homepage" = {
    id = "b0000001-0000-4000-8000-000000000001";
    url = "https://home.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 1000;
    isEssential = true;
  };
  "Home Assistant" = {
    id = "b0000001-0000-4000-8000-000000000002";
    url = "https://home-assistant.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 2000;
    isEssential = true;
  };
  "Node-RED" = {
    id = "b0000001-0000-4000-8000-000000000003";
    url = "https://red.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 3000;
    isEssential = true;
  };
  "Grafana" = {
    id = "b0000001-0000-4000-8000-000000000004";
    url = "https://grafana.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 4000;
    isEssential = true;
  };
  "Vaultwarden" = {
    id = "b0000001-0000-4000-8000-000000000006";
    url = "https://vault.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 6000;
    isEssential = true;
  };
  "n8n" = {
    id = "b0000001-0000-4000-8000-000000000007";
    url = "https://n8n.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 7000;
    isEssential = true;
  };
  "InfluxDB" = {
    id = "b0000001-0000-4000-8000-000000000008";
    url = "https://influxdb.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 8000;
    isEssential = true;
  };
  "OPNsense" = {
    id = "b0000001-0000-4000-8000-000000000009";
    url = "https://10.15.100.99:8443";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 9000;
    isEssential = true;
  };
  "Kanidm" = {
    id = "b0000001-0000-4000-8000-000000000010";
    url = "https://auth.czichy.com";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 10000;
    isEssential = true;
  };
  "Q-Cells" = {
    id = "b0000001-0000-4000-8000-000000000011";
    url = "https://qhome-ess-g3.q-cells.eu/#/login";
    workspace = smartHomeWorkspace;
    container = smartHomeContainer;
    position = 11000;
    isEssential = true;
  };
}
