guestName: guestCfg: {
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    flip
    mapAttrsToList
    mkDefault
    mkForce
    ;
in {
  specialArgs = guestCfg.extraSpecialArgs;
  #pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
  inherit (guestCfg) autostart;
  config = {
    imports =
      guestCfg.modules
      ++ [
        inputs.nixos-nftables-firewall.nixosModules.default
        (
          import ./common-guest-config.nix config.modules.users.primaryUser.authorizedKeys guestName
          guestCfg
        )
        (
          {config, ...}: {
            # Set early hostname too, so we can associate those logs to this host and don't get "localhost" entries in loki
            boot.kernelParams = ["systemd.hostname=${config.networking.hostName}"];
          }
        )
      ];

    # TODO needed because of https://github.com/NixOS/nixpkgs/issues/102137
    environment.noXlibs = mkForce false;
    lib.microvm.mac = guestCfg.microvm.mac;

    microvm = {
      hypervisor = mkDefault "cloud-hypervisor";
      socket = "control.socket";

      mem = mkDefault 1024;
      vcpu = mkDefault 2;

      # Add a writable store overlay, but since this is always ephemeral
      # disable any store optimization from nix.
      writableStoreOverlay = "/nix/.rw-store";

      # MACVTAP bridge to the host's network
      interfaces = [
        {
          type = "macvtap";
          id = "vm-${guestName}";
          inherit (guestCfg.microvm) mac;
          macvtap = {
            link = guestCfg.microvm.macvtap;
            mode = "bridge";
          };
        }
      ];

      shares =
        [
          # Share the nix-store of the host
          {
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            tag = "ro-store";
            proto = "virtiofs";
          }
        ]
        ++ flip mapAttrsToList guestCfg.zfs (
          _: zfsCfg: {
            source = zfsCfg.hostMountpoint;
            mountPoint = zfsCfg.guestMountpoint;
            tag = builtins.substring 0 16 (builtins.hashString "sha256" zfsCfg.hostMountpoint);
            proto = "virtiofs";
          }
        );
    };

    #networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = guestCfg.microvm.mac;
    systemd.network.networks."10-${guestCfg.networking.mainLinkName}".matchConfig = mkForce {
      MACAddress = guestCfg.microvm.mac;
    };
  };
}
