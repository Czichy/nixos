{
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  i18n.defaultLocale = "de_DE.UTF-8";
  console.keyMap = "de";
  time.timeZone = "Europe/Berlin";

  boot = {
    loader = {
      timeout = lib.mkForce 1;
      grub.enable = false;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };
    #binfmt.emulatedSystems = [ "aarch64-linux" ];
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "cifs"
      "f2fs"
      "jfs"
      "ntfs"
      "reiserfs"
      "vfat"
      "xfs"
    ];
  };

  users.users.czichy = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];

    # TODO: You can set an initial password for your user.
    # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
    # Be sure to change it (using passwd) after rebooting!
    initialPassword = "nixos";
  };

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
  ];

  users.users.czichy.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
  ];

  nix = {
    settings.trusted-users = ["root"];
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
