{
  config.tensorfiles.system = {
    impermanence = {
      enable = true;
      allowOther = true;
      btrfsWipe = {
        enable = false;
        rootPartition = "/dev/nvme0n1";
      };
    };
    users.usersSettings."root" = {
      uid = 0;
      gid = 0;
      agenixPassword.enable = true;
    };
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
  };
}
