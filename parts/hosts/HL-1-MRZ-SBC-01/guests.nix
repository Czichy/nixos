{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  ...
}: let
  macAddress_enp1s0 = "60:be:b4:19:a8:4c";
  macAddress_enp2s0 = "60:be:b4:19:a8:4d";
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
        modules = [
          ../../../globals/globals.nix
          ./guests/${guestName}.nix
          {
            #node.secretsDir = ./secrets/${guestName};
            networking.nftables.firewall = {
              zones.untrusted.interfaces = [
                config.tensorfiles.services.microvm.guests.${guestName}.networking.mainLinkName
              ];
            };
          }
        ];
      };
      mkMicrovm = guestName: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "enp2s0";
              # macvtap = "lan";
              baseMac = macAddress_enp2s0; # TODO move to config
            };
            # networking.address = "10.15.40.148/24";
            extraSpecialArgs = {
              inherit globals;
              inherit lib;
              inherit inputs;
            };
          };
      };
    in ({} // mkMicrovm "adguardhome" {enableStorageDataset = true;});
  };
}
