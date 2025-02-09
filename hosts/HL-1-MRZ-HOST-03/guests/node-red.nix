{hostName, ...}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
  microvm.mem = 512;
  microvm.vcpu = 1;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;

  networking.firewall = {
    allowedTCPPorts = [443 1880];
  };
  # |----------------------------------------------------------------------| #

  services.node-red = {
    enable = true;
    withNpmAndGcc = true;
    define = {"editorTheme.projects.enabled" = "true";};
  };
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        directory = "/root/.node-red/";
        mode = "0700";
      }
    ];
  };
  # |----------------------------------------------------------------------| #
  # topology.self.services.powermeter = {
  # info = "https://" + unifiDomain;
  # name = "Power Meter";
  # };
  # |----------------------------------------------------------------------| #
}
