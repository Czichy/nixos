{pkgs, ...}: {
  imports = [
    ./networking.nix
    ./test.nix
    # ../../../../modules/nixos/services/networking/ssh.nix
    # ../../../../modules/nixos/base/user-group.nix
    # ../../../../modules/base.nix
  ];

  microvm = {
    # Any other configuration for your MicroVM
    mem = 1024; # RAM allocation in MB
    vcpu = 1; # Number of Virtual CPU cores
    # It is highly recommended to share the host's nix-store
    # with the VMs to prevent building huge images.
    # shares can not be set to `neededForBoot = true;`
    # so if you try to use a share in boot script(such as system.activationScripts), it will fail!
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
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-test"; # should be prefixed with "vm-"
        mac = "02:00:00:00:00:02"; # Unique MAC address
      }
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
    hypervisor = "qemu";
    # Control socket for the Hypervisor so that a MicroVM can be shutdown cleanly
    socket = "control.socket";
  };
  users.defaultUserShell = pkgs.nushell;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
    # sshPubKey
  ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  system.stateVersion = "24.05";
}
