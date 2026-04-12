# Syncthing – nativ auf HOST-01 (kein MicroVM)
#
# Läuft direkt auf dem Host, damit kein virtiofs-Overhead entsteht.
# Syncthing greift direkt auf /shared/shares (ZFS storage-Pool) zu.
# Device-ID bleibt erhalten (gleiche cert/key wie vorher im MicroVM).
{
  config,
  inputs,
  ...
}: let
  secretsPath = inputs.private;
  dataDir = "/shared/shares";
  user = "czichy";
  group = "users";

  devices = {
    "HL-1-OZ-PC-01" = {
      id = "QBEVQY4-KBNMIBW-MTY7SEC-DNBDN7J-OL7HHJ7-K7S5EXD-MF3FAHZ-RRFBHAR";
      autoAcceptFolders = false;
    };
  };
in {
  age.secrets.syncthingCert = {
    symlink = true;
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/syncthing/cert.pem.age";
    mode = "0600";
    owner = user;
  };
  age.secrets.syncthingKey = {
    symlink = true;
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/syncthing/key.pem.age";
    mode = "0600";
    owner = user;
  };

  networking.firewall.allowedTCPPorts = [8384 22000];
  networking.firewall.allowedUDPPorts = [22000 21027];

  services.syncthing = {
    enable = true;
    configDir = "/home/${user}/.config/syncthing";
    inherit dataDir user group;
    cert = config.age.secrets.syncthingCert.path;
    key = config.age.secrets.syncthingKey.path;
    guiAddress = "0.0.0.0:8384";
    settings = {
      overrideDevices = true;
      overrideFolders = true;
      inherit devices;
      folders = {
        "iykxy-ruk4y" = {
          path = "${dataDir}/dokumente";
          devices = ["HL-1-OZ-PC-01"];
        };
        "lhqxb-zc6qj" = {
          path = "${dataDir}/users/christian/Trading";
          devices = ["HL-1-OZ-PC-01"];
        };
      };
      options.globalAnnounceEnabled = false;
      gui.insecureSkipHostcheck = true;
      gui.insecureAdminAccess = true;
    };
  };

  systemd.services.syncthing.serviceConfig.UMask = "0007";
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  environment.persistence."/persist".directories = [
    {
      directory = "/home/${user}/.config/syncthing";
      inherit user group;
      mode = "0700";
    }
  ];
}
