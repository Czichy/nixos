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
        enableTradingDataset ? false,
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
            ../../modules/ente.nix
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
      # TODO: calculate mac
      // mkMicrovm "samba" "HL-3-RZ-SMB-01" "enp38s0" "02:01:27:d7:9e:16" "vlan40" {
        enableStorageDataset = true;
        enableBunkerDataset = true;
        enablePaperlessDataset = true;
        enableSharedDataset = true;
      }
      // mkMicrovm "ente" "HL-3-RZ-ENTE-01" "enp38s0" "02:01:27:ee:9e:16" "vlan40" {
        enableStorageDataset = true;
        enableBunkerDataset = true;
        enableSharedDataset = true;
      }
      // mkMicrovm "syncthing" "HL-3-RZ-SYNC-01" "enp38s0" "02:01:27:6b:d9:d4" "vlan40" {
      }
      // mkMicrovm "influxdb" "HL-3-RZ-INFLUX-01" "enp38s0" "02:01:27:dc:85:68" "vlan40" {
        enableStorageDataset = true;
      }
      // mkMicrovm "forgejo" "HL-3-RZ-GIT-01" "enp38s0" "02:01:27:c4:0e:09" "vlan40" {
        enableStorageDataset = true;
      }
      // mkMicrovm "ibkr-flex" "HL-3-RZ-IBKR-01" "enp38s0" "02:01:27:ff:ed:77" "vlan40" {
      }
    );
  };

  systemd.tmpfiles.settings = {
    "10-samba-shares" = {
      "/storage/shares/bibliothek".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/media".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/dokumente".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/dokumente/scanned_documents".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/users".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/users/christian".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
      "/storage/shares/users/ina".d = {
        user = "root";
        group = "root";
        mode = "0777";
      };
    };
  };
}
