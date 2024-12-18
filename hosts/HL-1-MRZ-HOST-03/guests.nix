{
  config,
  lib,
  inputs,
  globals,
  nodes,
  ...
}: {
  tensorfiles.services.microvm = {
    enable = true;
    guests = let
      mkGuest = guestName: {
        enableStorageDataset ? false,
        enableBunkerDataset ? false,
        ...
      }: {
        autostart = true;
        zfs."/state" = {
          # TODO make one option out of that? and split into two readonly options automatically?
          pool = "rpool";
          dataset = "local/guests/${guestName}";
        };
        zfs."/persist" = {
          pool = "rpool";
          dataset = "safe/guests/${guestName}";
        };
        zfs."/storage" = lib.mkIf enableStorageDataset {
          pool = "storage";
          dataset = "safe/guests/${guestName}";
        };
        zfs."/bunker" = lib.mkIf enableBunkerDataset {
          pool = "storage";
          dataset = "bunker/guests/${guestName}";
        };
        modules =
          [
            ../config/default.nix
            ../../modules/globals.nix
            ./guests/${guestName}.nix
            {
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
      // mkMicrovm "unifi" "HL-3-RZ-UNIFI-01" "servers" "02:05:27:11:7f:17" "vlan40" {
        enableStorageDataset = true;
      }
    );
  };
}
