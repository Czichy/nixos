{lib, ...}:
with lib; let
  inherit (lib) mkEnableOption;
  inherit
    (lib)
    mkImpermanenceEnableOption
    ;
in {
  options.modules.system.virtualization = {
    enable = mkEnableOption "virtualization";
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    libvirt = {enable = mkEnableOption "libvirt";};
    docker = {enable = mkEnableOption "docker";};
    podman = {enable = mkEnableOption "podman";};
    qemu = {enable = mkEnableOption "qemu";};
    waydroid = {enable = mkEnableOption "waydroid";};
    distrobox = {enable = mkEnableOption "distrobox";};
    microvm = {enable = mkEnableOption "microvm";};
  };
}
