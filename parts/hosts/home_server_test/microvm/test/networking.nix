{...}: let
  # hostName = "test";
  # inherit (myvars.networking) mainGateway nameservers;
  # inherit (myvars.networking.hostsAddr.${hostName}) ipv4;
  # ipv4WithMask = "${ipv4}/24";
  ipv4 = "192.168.1.177";
  mainGateway = "192.168.1.1";
  nameservers = [
    "119.29.29.29" # DNSPod
    "223.5.5.5" # AliDNS
  ];
  ipv4WithMask = "${ipv4}/24";
in {
  systemd.network.enable = true;

  systemd.network.networks."20-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [ipv4WithMask];
      Gateway = mainGateway;
      DNS = nameservers;
      DHCP = "no";
    };
  };
}
