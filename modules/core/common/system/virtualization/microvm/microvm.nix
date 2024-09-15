guestName: guestCfg: {
  config,
  pubkeys,
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
  pubkeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPMF0Sz9e6JoHudF11U2F9U/S5KFINlU9556C2zA82X czichy@vmtest"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHsXDsMxnu+pECq4+aJyBk59ASKbr8ENLGeb/ncrJ4T8 czichy@homeservertest"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKQgoSENg960XY9wU77q8p1+4WgUhEb10xlc27RWcmNE czichy@desktop"
  ];
in {
  specialArgs = guestCfg.extraSpecialArgs;
  #pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
  inherit (guestCfg) autostart;

  config = {
    imports =
      guestCfg.modules
      ++ [
        inputs.nix-topology.nixosModules.default
        inputs.nixos-nftables-firewall.nixosModules.default
        (
          import ./common-guest-config.nix pubkeys guestName guestCfg
          #import ./common-guest-config.nix config.modules.users.primaryUser.authorizedKeys guestName
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
      hypervisor = mkDefault "qemu";
      # hypervisor = mkDefault "cloud-hypervisor";
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
          # MAC address of the guest’s network interface
          # mac = "60:be:b4:19:a8:4f";
          inherit (guestCfg.microvm) mac;
          macvtap = {
            # Attach network interface to host interface for type = “macvlan”
            link = "servers"; #guestCfg.microvm.macvtap;
            mode = "bridge";
          };
        }
        # {
        #   type = "user";
        #   id = "qemu";
        #   mac = "02:00:00:01:01:01";
        # }
        # {
        #   type = "tap";
        #   id = "vm-40-${builtins.substring 0 9 guestName}";
        #   mac = "5E:A4:B9:D2:F8:03";
        # }
      ];

      # Block device images for persistent storage
      # microvm use tmpfs for root(/), so everything else
      # is ephemeral and will be lost on reboot.
      #
      # you can check this by running `df -Th` & `lsblk` in the VM.
      volumes = [
        {
          mountPoint = "/var";
          image = "var.img";
          size = 512;
        }
        {
          mountPoint = "/etc";
          image = "etc.img";
          size = 50;
        }
      ];

      shares = [
        {
          # It is highly recommended to share the host's nix-store
          # with the VMs to prevent building huge images.
          # a host's /nix/store will be picked up so that no
          # squashfs/erofs will be built for it.
          #
          # by this way, /nix/store is readonly in the VM,
          # and thus the VM can't run any command that modifies
          # the store. such as nix build, nix shell, etc...
          # if you want to run nix commands in the VM, see
          # https://github.com/astro/microvm.nix/blob/main/doc/src/shares.md#writable-nixstore-overlay
          tag = "ro-store"; # Unique virtiofs daemon tag
          proto = "virtiofs"; # virtiofs is faster than 9p
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          # On the host
          source = "/var/lib/microvms/${config.networking.hostName}/journal";
          # In the MicroVM
          mountPoint = "/var/log/journal";
          tag = "journal";
          proto = "virtiofs";
          socket = "journal.sock";
        }
      ];
      #++ flip mapAttrsToList guestCfg.zfs (
      #  _: zfsCfg: {
      #    source = zfsCfg.hostMountpoint;
      #    mountPoint = zfsCfg.guestMountpoint;
      #    tag = builtins.substring 0 16 (builtins.hashString "sha256" zfsCfg.hostMountpoint);
      #    proto = "virtiofs";
      #  }
      # );
    };

    # networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = guestCfg.microvm.mac;
    systemd.network.networks."10-${guestCfg.networking.mainLinkName}".matchConfig = mkForce {
      MACAddress = guestCfg.microvm.mac;
    };
  };
}
