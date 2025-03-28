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
  #   ipv4 = "10.46.0.1";
  #   server = {
  #     host = config.networking.fqdn;
  #     port = 51820;
  #     reservedAddresses = [
  #       "10.46.0.1/24"
  #       "fd00:43::/120"
  #     ];
  #     openFirewall = true;
  #   };
  # };
}
