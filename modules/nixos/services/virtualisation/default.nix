{localFlake}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
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
        libvirtd = {
          enable = true;
          onBoot = "ignore";

          qemu = {
            # qemu_full enables cephSupport which pulls in ceph → arrow-cpp → broken boost_system.
            # Use qemu without ceph since we don't use Ceph storage.
            package = pkgs.qemu;
            # ovmf.enable = true;
            # ovmf.packages =
            #   if pkgs.stdenv.isx86_64
            #   then [pkgs.OVMFFull.fd]
            #   else [pkgs.OVMF.fd];
            swtpm.enable = true;
            swtpm.package = pkgs.swtpm;
            runAsRoot = false;
          };
        };
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
        virtio-win
        win-spice
        looking-glass-client
        adwaita-icon-theme # default gnome cursors
        glib
      ];
      environment.etc = {
        "ovmf/edk2-x86_64-secure-code.fd" = {
          source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-x86_64-secure-code.fd";
        };

        "ovmf/edk2-i386-vars.fd" = {
          source = config.virtualisation.libvirtd.qemu.package + "/share/qemu/edk2-i386-vars.fd";
        };
      };
    }
    # |----------------------------------------------------------------------| #
    {
      # Workaround for nixpkgs regression: virt-secret-init-encryption.service
      # hardcodes /usr/bin/sh which doesn't exist on NixOS.
      # https://github.com/NixOS/nixpkgs/issues/XXXXX
      systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${pkgs.bash}/bin/sh -c 'umask 0077 && (dd if=/dev/random status=none bs=32 count=1 | systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
      ];
    }
    # |----------------------------------------------------------------------| #
    {
      programs.dconf.enable = true;
      # dconf.settings = {
      #   "org/virt-manager/virt-manager/connections" = {
      #     autoconnect = ["qemu:///system"];
      #     uris = ["qemu:///system"];
      #   };
      # };
    }
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = [
          "/var/lib/libvirt"
          # systemd credential.secret muss mit dem verschlüsselten libvirt-Key übereinstimmen.
          # Ohne Persistenz: nach Reboot neues credential.secret → alter Key nicht mehr entschlüsselbar
          # → libvirtd schlägt mit status=243/CREDENTIALS fehl.
          "/var/lib/systemd"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
