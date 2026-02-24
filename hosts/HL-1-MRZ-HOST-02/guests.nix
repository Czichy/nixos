{
  config,
  lib,
  inputs,
  globals,
  nodes,
  ...
}:
# let
# macAddress_enp4s0 = "60:be:b4:19:a8:4f";
# in
{
  tensorfiles.services.microvm = {
    enable = true;
    guests = let
      mkGuest = guestName: {enableStorageDataset ? false, ...}: {
        autostart = true;
        modules =
          [
            # inputs.self.globals
            ../config/default.nix
            ../../modules/globals.nix
            ./guests/${guestName}.nix
            {
              #node.secretsDir = ./secrets/${guestName};
              networking.nftables.firewall = {
                zones.untrusted.interfaces = [
                  config.tensorfiles.services.microvm.guests.${guestName}.networking.mainLinkName
                ];
              };
            }
          ]
          ++ (inputs.nixpkgs.lib.attrValues inputs.self.nixosModules);
      };
      mkMicrovm = guestName: hostName: macvtap: mac: net: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "${macvtap}";
              mac = mac;
              # macvtap = "lan";
              # baseMac = macAddress_enp4s0; # TODO move to config
            };
            networking.address = globals.net."${net}".hosts."${hostName}".cidrv4;
            networking.gateway = globals.net."${net}".hosts.HL-3-MRZ-FW-01.ipv4;
            extraSpecialArgs = {
              inherit (inputs.self) secretsPath;
              inherit globals nodes;
              inherit lib;
              inherit inputs;
              inherit hostName;
            };
          };
      };
    in (
      {}
      // mkMicrovm "adguardhome" "HL-3-RZ-DNS-01" "servers" "02:01:27:b8:35:04" "vlan40" {enableStorageDataset = true;}
      // mkMicrovm "vaultwarden" "HL-3-RZ-VAULT-01" "servers" "02:01:27:0d:dc:b1" "vlan40" {enableStorageDataset = true;}
      # // mkMicrovm "nginx" "dmz" "vlan70" {enableStorageDataset = true;}
      // mkMicrovm "caddy" "HL-3-DMZ-PROXY-01" "dmz" "02:01:27:53:4a:97" "vlan70" {enableStorageDataset = true;}
      // mkMicrovm "kanidm" "HL-3-RZ-AUTH-01" "servers" "02:02:27:b8:35:04" "vlan40" {}
    );
  };
}
