# --- parts/modules/nixos/services/networking/networkmanager.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{ localFlake }:
{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
let
  inherit (localFlake.lib.tensorfiles) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence = if impermanenceCheck then config.tensorfiles.system.impermanence else { };
in
{
  options.tensorfiles.services.virtualisation = with types; {
    enable = mkEnableOption ''
      Enables NixOS module that configures/handles the libvirt service.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      virtualisation = {
        libvirtd.enable = true;
        libvirtd.onBoot = "ignore";
        libvirtd.qemu.package = pkgs.qemu_full;
        libvirtd.qemu.ovmf.enable = true;
        libvirtd.qemu.ovmf.packages =
          if pkgs.stdenv.isx86_64 then [ pkgs.OVMFFull.fd ] else [ pkgs.OVMF.fd ];
        libvirtd.qemu.swtpm.enable = true;
        libvirtd.qemu.swtpm.package = pkgs.swtpm;
        libvirtd.qemu.runAsRoot = false;
        spiceUSBRedirection.enable = true; # Note that this allows users arbitrary access to USB devices.
        podman.enable = true;
      };
      environment.systemPackages = with pkgs; [
        qemu_kvm
        virt-manager
        virt-viewer
        spice
        spice-gtk
        spice-protocol
        win-virtio
        win-spice
        looking-glass-client
        gnome3.adwaita-icon-theme # default gnome cursors
        glib
      ];
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [ "/var/lib/libvirt" ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [ czichy ];
}
