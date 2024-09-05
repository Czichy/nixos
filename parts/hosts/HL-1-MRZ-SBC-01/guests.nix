{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  secretsPath,
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
        modules = [
          ../config/default.nix
          ../../../modules/core/deterministic_ids.nix
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
        # ++ (inputs.nixpkgs.lib.attrValues config.flake.nixosModules);
      };
      mkMicrovm = guestName: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "enp4s0";
              # macvtap = "lan";
              # baseMac = macAddress_enp4s0; # TODO move to config
            };
            networking.address = globals.net.vlan40.hosts."HL-1-MRZ-SBC-01-${guestName}".cidrv4;
            networking.gateway = globals.net.vlan40.hosts.opnsense.ipv4;
            extraSpecialArgs = {
              inherit secretsPath;
              inherit globals;
              inherit lib;
              inherit inputs;
            };
          };
      };
    in (
      {}
      // mkMicrovm "adguardhome" {enableStorageDataset = true;}
      // mkMicrovm "vaultwarden" {enableStorageDataset = true;}
      # // mkMicrovm "unifi" {enableStorageDataset = true;}
    );
  };
}
