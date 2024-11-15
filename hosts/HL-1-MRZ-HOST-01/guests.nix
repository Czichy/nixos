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
        enableSharedDataset ? false,
        enablePaperlessDataset ? false,
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
        zfs."/shared" = lib.mkIf enableSharedDataset {
          pool = "storage";
          dataset = "bunker/shared";
          hostMountpoint = "/shared";
        };
        zfs."/paperless" = lib.mkIf enablePaperlessDataset {
          pool = "storage";
          dataset = "bunker/paperless";
          hostMountpoint = "/paperless";
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
      mkMicrovm = guestName: hostName: macvtap: net: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "${macvtap}";
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
      // mkMicrovm "samba" "HL-3-RZ-SMB-01" "enp4s0" "vlan40" {
        enableStorageDataset = true;
        enableBunkerDataset = true;
        enablePaperlessDataset = true;
        enableSharedDataset = true;
      }
      // mkMicrovm "influxdb" "HL-3-RZ-INFLUX-01" "enp4s0" "vlan40" {
        enableStorageDataset = true;
      }
      // mkMicrovm "syncthing" "HL-3-RZ-SYNC-01" "enp4s0" "vlan40" {
        enableSharedDataset = true;
      }
    );
  };
}
