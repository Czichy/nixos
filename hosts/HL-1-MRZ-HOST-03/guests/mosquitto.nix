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
    allowedTCPPorts = [1883];
  };
  # |----------------------------------------------------------------------| #
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        acl = ["pattern readwrite #"];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
      # {
      #   address = "0.0.0.0";
      #   users."admin" = {
      #     passwordFile = config.sops.secrets.mosquitto-users-admin.path;
      #     acl = [
      #       "readwrite #"
      #     ];
      #   };
      #   users."hass" = {
      #     passwordFile = config.sops.secrets.mosquitto-users-hass.path;
      #     acl = [
      #       "readwrite #"
      #     ];
      #   };
      #   users."plugs" = {
      #     passwordFile = config.sops.secrets.mosquitto-users-plugs.path;
      #     acl = [
      #       "readwrite tele/#"
      #       "readwrite cmnd/#"
      #       "readwrite stat/#"
      #       "readwrite tasmota/#"
      #     ];
      #   };
      # }
    ];
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
  # |----------------------------------------------------------------------| #
  # topology.self.services.powermeter = {
  # info = "https://" + unifiDomain;
  # name = "Power Meter";
  # };
  # |----------------------------------------------------------------------| #
}
