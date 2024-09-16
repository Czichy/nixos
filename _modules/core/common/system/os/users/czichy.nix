{...}: {
  config.modules.system.users.usersSettings."czichy" = {
    isMainUser = true;
    isSudoer = true;
    isNixTrusted = true;
    useHomeManager = true;
    uid = 1000;
    gid = 1000;
    agenixPassword.enable = true;
    extraGroups = [
      "video"
      "audio"
      "networkmanager"
      "input"
      # ]
      # ++ ifTheyExist [
      "camera"
      "deluge"
      "docker"
      "git"
      "i2c"
      "kvm"
      "libvirt"
      "libvirtd"
      "network"
      "nitrokey"
      "podman"
      "qemu-libvirtd"
      "wireshark"
      "flatpak"
    ];
  };
}
