{
  config,
  inputs,
  globals,
  ...
}
: let
  inherit (inputs.self) lib;
in {
  networking.domain = globals.domains.me;
  # wireguard.proxy-vps = {
  #   client.via = "HL-4-PAZ-PROXY";
  #   ipv4 = "10.46.0.1";
  #   # firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.vaultwarden.config.rocketPort];
  # };
  wireguard.proxy-vps = {
    ipv4 = "10.46.0.1";
    server = {
      host = config.networking.fqdn;
      port = 51820;
      reservedAddresses = [
        "10.46.0.1/24"
        "fd00:43::/120"
      ];
      openFirewall = true;
    };
  };
}
