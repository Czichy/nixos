{
  pkgs,
  secretsPath,
  hostName,
  lib,
  inputs,
  ...
}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
  microvm.mem = 512;
  microvm.vcpu = 1;
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
    pkg-config
    openssh
    inputs.self.packages.${system}.ibkr-rust
    # inputs.ibkr-rust.packages.${pkgs.system}.flex
  ];

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
  # fileSystems = lib.mkMerge [
  #   {
  #     "/shared".neededForBoot = true;
  #   }
  # ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
