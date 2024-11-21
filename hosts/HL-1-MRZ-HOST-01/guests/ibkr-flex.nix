{
  pkgs,
  secretsPath,
  hostName,
  lib,
  ...
}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
  # microvm.mem = 1024 * 3;
  # microvm.vcpu = 4;
  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/users/christian/Trading/TWS_Flex_Reports";
      # In the MicroVM
      mountPoint = "/TWS_Flex_Reports";
      tag = "flex";
      proto = "virtiofs";
    }
  ];

  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  age.secrets = {
    ibkrFlexToken = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ibkr-flex/token.age";
      mode = "0600";
      owner = "root";
    };
  };
  # |----------------------------------------------------------------------| #
  # networking.firewall = {
  #   allowedTCPPorts = [
  #     8384 # Port for Syncthing Web UI.
  #     22000 # TCP based sync protocol traffic
  #   ];
  #   allowedUDPPorts = [
  #     22000 # QUIC based sync protocol traffic
  #     21027 # for discovery broadcasts on IPv4 and multicasts on IPv6
  #   ];
  # };
  # ------------------------------
  # | SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    openssh
    inputs.ibkr-rust.packages.${pkgs.system}.flex
  ];

  # |----------------------------------------------------------------------| #
  fileSystems = lib.mkMerge [
    {
      "/shared".neededForBoot = true;
    }
  ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
