{
  config,
  lib,
  inputs,
  globals,
  nodes,
  ...
}: let
  macAddress_enp4s0 = "60:be:b4:19:a8:4f";
in {
  tensorfiles.services.microvm = {
    enable = true;
    guests = let
      mkGuest = guestName: {enableStorageDataset ? false, ...}: {
        autostart = true;
        # temporary state that is wiped on reboot
        # zfs."/state" = {
        #   pool = "rpool";
        #   dataset = "rpool/encrypted/vms/${guestName}";
        # };
        # persistent state
        # zfs."/persist" = {
        #   pool = "rpool";
        #   dataset = "rpool/encrypted/safe/vms/${guestName}";
        # };
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
      mkMicrovm = guestName: net: macvtap: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "servers";
              # macvtap = "lan";
              # baseMac = macAddress_enp4s0; # TODO move to config
            };
            networking.address = globals.net."${net}".hosts."${config.node.name}-${guestName}".cidrv4;
            networking.gateway = globals.net."${net}".hosts.opnsense.ipv4;
            extraSpecialArgs = {
              inherit (inputs.self) secretsPath;
              inherit globals nodes;
              inherit lib;
              inherit inputs;
            };
          };
      };
    in (
      {}
      // mkMicrovm "adguardhome" "servers" "vlan40" {enableStorageDataset = true;}
      // mkMicrovm "vaultwarden" "servers" "vlan40" {enableStorageDataset = true;}
      // mkMicrovm "nginx" "dmz" "vlan70" {enableStorageDataset = true;}
    );
  };
}
