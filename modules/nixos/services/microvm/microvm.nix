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
  inherit (inputs) self;
  pubkeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
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
        )
        (
          {config, ...}: {
            # Set early hostname too, so we can associate those logs to this host and don't get "localhost" entries in loki
            boot.kernelParams = ["systemd.hostname=${config.networking.hostName}"];
          }
        )
      ];

    # # TODO needed because of https://github.com/NixOS/nixpkgs/issues/102137
    # environment.noXlibs = mkForce false;
    lib.microvm.mac = guestCfg.microvm.mac;

    microvm = {
      hypervisor = mkDefault "qemu";
      # hypervisor = mkDefault "cloud-hypervisor";
      socket = "control.socket";

      mem = mkDefault 1024;
      vcpu = mkDefault 2;

      # This causes QEMU rebuilds which would remove 200MB from the closure but
      # recompiling QEMU every deploy is worse.
      optimize.enable = false;

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
            link = guestCfg.microvm.macvtap;
            # link = "servers"; #guestCfg.microvm.macvtap;
            mode = "bridge";
          };
        }
      ];

      # Block device images for persistent storage
      # microvm use tmpfs for root(/), so everything else
      # is ephemeral and will be lost on reboot.
      #
      # you can check this by running `df -Th` & `lsblk` in the VM.
      # volumes = [
      #   {
      #     mountPoint = "/var";
      #     image = "var.img";
      #     size = 1024;
      #   }
      #   {
      #     mountPoint = "/etc";
      #     image = "etc.img";
      #     size = 50;
      #   }
      # ];

      shares =
        [
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
          {
            # On the host
            source = "/etc/vm-persist/${config.networking.hostName}";
            # In the MicroVM
            mountPoint = "/persist";
            tag = "persist";
            proto = "virtiofs";
          }
          {
            # On the host
            source = "/var/cache/${config.networking.hostName}";
            # In the MicroVM
            mountPoint = "/var/cache";
            tag = "cache";
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
    systemd.tmpfiles.rules = [
      "d /var/lib/microvms/${guestName}/journal 0755 root root - -"
      "d /etc/vm-persist${guestName}/journal 0755 root root - -"
      "d /var/cache/${guestName}/journal 0755 root root - -"
    ];
    # systemd.tmpfiles.settings = {
    #   "10-microvm-shares-${guestName}" = {
    #     "/var/lib/microvms/${guestName}/journal".d = {
    #       user = "root";
    #       group = "root";
    #       mode = "0777";
    #     };
    #     "/etc/vm-persist/${guestName}".d = {
    #       user = "root";
    #       group = "root";
    #       mode = "0777";
    #     };
    #     "/var/cache/${guestName}".d = {
    #       user = "root";
    #       group = "root";
    #       mode = "0777";
    #     };
    #   };
    # };

    # networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = guestCfg.microvm.mac;
    systemd.network.networks."10-${guestCfg.networking.mainLinkName}".matchConfig = mkForce {
      MACAddress = guestCfg.microvm.mac;
    };
  };
}
