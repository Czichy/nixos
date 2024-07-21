{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  ...
}: {
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
        # networking = config.repo.secrets.home-ops.guests.${guestName}.networking;
        networking = {
          mainLinkName = "";
          address = globals.net.home-wan.hosts.ward.cidrv4;
          gateway = globals.net.home-wan.hosts.fritzbox.ipv4;
          dns = "";
        };
      };
      mkMicrovm = guestName: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "brprim4";
              baseMac = "1c:69:7a:00:00:00"; # TODO move to config
            };
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
