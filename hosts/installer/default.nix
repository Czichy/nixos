{
  pkgs,
  modulesPath,
  lib,
  ...
}:
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
  services.openssh.enable = true;
  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";
  time.timeZone = "Europe/Berlin";
  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.timeout = lib.mkForce 1;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.supportedFilesystems = lib.mkForce [
    "btrfs"
    "cifs"
    "f2fs"
    "jfs"
    "ntfs"
    "reiserfs"
    "vfat"
    "xfs"
  ];
  users.users.root.openssh.authorizedKeys.keys = [

    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
  ];

  nix = {
    settings.trusted-users = [ "root" ];
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
      tarball-ttl = 900
    '';
  };

  # Use helix as the default editor
  environment.variables.EDITOR = "hx";

  environment.systemPackages = with pkgs; [
    git
    nixos-install-tools
    btrfs-progs
    jq
    helix
    vim
    curl
    wget
    httpie
    diskrsync
    partclone
    ntfsprogs
    ntfs3g
  ];
}
