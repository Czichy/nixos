{
  config,
  lib,
  inputs,
  globals,
  nodes,
  ...
}: {
  # USB pass-through for power meter
  services.udev.extraRules = ''
    # Lesekopf - Silicon_Labs_CP2104_USB_to_UART_Bridge_Controller_015ACA59
    SUBSYSTEM=="usb", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", GROUP="kvm"
  '';
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
      # // mkMicrovm "minecraft" "HL-3-RZ-MC-01" "servers" "02:04:27:11:8f:17" "vlan40" {
      #   enableStorageDataset = true;
      # }
      // mkMicrovm "powermeter" "HL-3-RZ-POWER-02" "servers" "02:04:27:12:8f:17" "vlan40" {
        enableStorageDataset = true;
      }
    );
  };
}
