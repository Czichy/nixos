{
  config,
  lib,
  ...
}: {
  config.tensorfiles.system = {
    users.usersSettings."czichy" = {
      isSudoer = true;
      isNixTrusted = true;
      uid = 1000;
      gid = 1000;
      agenixPassword.enable = true;
      extraGroups = [
        "networkmanager"
        "input"
        "docker"
        "kvm"
        "libvirt"
        "libvirtd"
        "network"
        "podman"
        "qemu-libvirtd"
      ];
    };
    impermanence = {
      enable = true;
      allowOther = true;
    };
    zfs.disks = {
      enable = true;
      zfs = {
        enable = true;
        hostId = builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName);
        root.impermanenceRoot = true;
        # root = {
        #   disk1 = "nvme0n1";
        # };
      };
    };
  };
}
