{
  config,
  inputs,
  ...
}
: let
  inherit (inputs.self) lib;
in {
  wireguard.proxy-public.server = {
    host = config.networking.fqdn;
    port = 51820;
    reservedAddresses = ["10.46.0.0/24" "fd00:43::/120"];
    openFirewall = true;
  };
}
