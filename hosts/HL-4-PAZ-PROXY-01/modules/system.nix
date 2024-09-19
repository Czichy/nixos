{
  config,
  lib,
  ...
}: {
  config.tensorfiles.system = {
    users.usersSettings."czichy" = lib.mkForce {
      isSudoer = true;
      isNixTrusted = true;
      agenixPassword.enable = true;
      extraGroups = [
        "networkmanager"
        "input"
        "docker"
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
