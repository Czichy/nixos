{
  config.tensorfiles.system = {
    impermanence = {
      enable = true;
      allowOther = true;
    };

    # users.usersSettings."root" = {
    #   agenixPassword.enable = true;
    #   uid = 0;
    #   gid = 0;
    # };
    # users.usersSettings."czichy" = {
    #   isSudoer = true;
    #   isNixTrusted = true;
    #   uid = 1000;
    #   gid = 1000;
    #   agenixPassword.enable = true;
    #   extraGroups = [
    #     "video"
    #     "audio"
    #     "networkmanager"
    #     "input"
    #     # ]
    #     # ++ ifTheyExist [
    #     "camera"
    #     "deluge"
    #     "docker"
    #     "git"
    #     "i2c"
    #     "kvm"
    #     "libvirt"
    #     "libvirtd"
    #     "network"
    #     "nitrokey"
    #     "podman"
    #     "qemu-libvirtd"
    #     "wireshark"
    #     "flatpak"
    #   ];
    # };
  };
}
