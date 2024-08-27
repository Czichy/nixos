{
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}: let
  runtimeDiskDirectory =
    if enablePersistentImage
    then "/shared/container"
    else "/home/x";

  runtimeDiskPath = "${runtimeDiskDirectory}/vm.qcow2";

  enablePersistentImage = true;
  memoryMegabytes = 4096;
  persistenceSize = "64G";

  vmXmlRaw = ./opnsense.xml;

  vmXml = pkgs.runCommand "opnsense.xml" {} ''
    sed \
      -e 's,@runtimeDiskPath@,${runtimeDiskPath},' \
      -e 's,@memoryKilobytes@,${toString (memoryMegabytes * 1024)},' \
      < ${vmXmlRaw} > $out
  '';

  networkXml = pkgs.writeText "network.xml" ''
    <network>
      <name>opnsense-network</name>
      <forward mode='bridge'/>
      <bridge name='vbr0' />
    </network>
  '';

  mkDisk = pkgs.callPackage ./mk-disk.nix {};

  vmQcow2 = mkDisk {
    inherit persistenceSize;
  };

  containerXauthority = pkgs.callPackage ./container-xauthority.nix {};
in {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  config = {
    system.build.kaliNow = {
      inherit vmXml networkXml vmQcow2;
      inherit containerXauthority;
    };

    system.stateVersion = config.system.nixos.release;

    boot.isContainer = true;

    networking.useDHCP = false;
    networking.resolvconf.enable = false;

    # TODO these should work
    # networking.resolvconf.enable = true;
    # networking.useHostResolvConf = true;

    # HACK networking.useHostResolvConf broken, this causes failed ln rather than overwriting
    environment.etc."resolv.conf".text = "";

    # revert from minimal.nix avoid rebuilds
    environment.noXlibs = false;

    nix.enable = false;

    # services.udev.enable = lib.mkForce true;

    # services.getty.autologinUser = "root";

    # NOTE container=docker is for https://systemd.io/CONTAINER_INTERFACE/

    system.build.kaliNow.containerInit = pkgs.writeScript "x.sh" ''
      #!${pkgs.runtimeShell}
      exec ${pkgs.coreutils}/bin/env -i container=docker ${config.system.build.toplevel}/init
    '';

    networking.firewall.enable = false;

    # networking.firewall.enable = true;
    # networking.firewall.logRefusedPackets = true;
    # networking.firewall.allowedUDPPorts = [ 53 67 ];

    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.allowedBridges = [
      "vbr0"
    ];
    virtualisation.libvirtd.qemu.verbatimConfig = ''
      user = "x"
      group = "users"
    '';

    virtualisation.spiceUSBRedirection.enable = true;

    security.polkit.debug = true;

    programs.virt-manager.enable = true;

    # ids.uids.qemu-libvirtd = lib.mkForce 1000;
    # users.users.qemu-libvirtd.isSystemUser = true;

    users.users.x = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = ["wheel" "libvirtd"];
    };

    security.sudo.wheelNeedsPassword = false;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.spice-space.lowlevelusbaccess" && subject.isInGroup("wheel")){
          return polkit.Result.YES;
        }
      });
    '';

    # services.dnsmasq = {
    #   enable = true;
    #   resolveLocalQueries = false;
    #   settings = {
    #     interface = "vbr0";
    #     dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0,96h";
    #     dhcp-option = [
    #       "option:router,192.168.122.1"
    #       "option:dns-server,192.168.122.1"
    #     ];
    #     # log-dhcp = true;
    #     # log-queries = true;
    #   };
    # };

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        strict-order = true;
        except-interface = "lo";
        bind-dynamic = true;
        interface = "vbr0";
        dhcp-range = "192.168.122.2,192.168.122.254,255.255.255.0";
        dhcp-no-override = true;
        dhcp-authoritative = true;
        dhcp-lease-max = "253";
      };
    };

    # # TODO doesn't work
    # networking.localCommands = ''
    #   ${config.system.build.setupVMNetwork}/bin/*
    # '';

    systemd.services = {
      lab-setup-vm-network = {
        requires = ["network.target"];
        wantedBy = ["multi-user.target"];
        unitConfig.ConditionCapability = "CAP_NET_ADMIN";
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          ${config.system.build.lab.setupVMNetwork}/bin/*
        '';
      };
    };

    system.build.lab.setupVMNetwork = pkgs.writeShellApplication {
      name = "lab-setup-vm-network";
      runtimeInputs = with pkgs; [
        iproute2
        iptables
      ];
      checkPhase = false;
      text = ''
        br_addr="192.168.122.1"
        br_dev="vbr0"
        ip link add name $br_dev type bridge
        ip link set $br_dev up
        ip addr add $br_addr/24 dev $br_dev
        iptables -t nat -F
        iptables -t nat -A POSTROUTING -s $br_addr/24 ! -o $br_dev -j MASQUERADE
      '';
    };
    # ip link add $br_dev type bridge stp_state 1 forward_delay 0
    # ip link set $br_dev up

    networking.nat.enable = true;
    # networking.nat.internalIPs = [ "192.168.122.0/24" ];
    # networking.nat.externalInterface = "eth0";

    systemd.services = {
      lab-setup-vm-rest = {
        after = ["lab-setup-vm-network.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        serviceConfig.User = "x";
        script = ''
          ${config.system.build.lab.setupVMRest}/bin/*
        '';
      };
    };

    system.build.lab.setupVMRest = pkgs.writeShellApplication {
      name = "lab-setup-vm-rest";
      runtimeInputs = with pkgs; [
        qemu
        libvirt
      ];
      runtimeEnv = {
        LIBVIRT_DEFAULT_URI = "qemu:///system";
      };
      checkPhase = false;
      text = ''
        shared_root=/shared
        shared_dirs="$shared_root/container $shared_root/vm"
        for d in $shared_dirs; do
          mkdir -p $d
        done

        mkdir -p $(dirname ${runtimeDiskPath})

        if [ ! -f ${runtimeDiskPath} ]; then
          qemu-img create -f qcow2 -o backing_fmt=qcow2 -o backing_file=${vmQcow2} ${runtimeDiskPath}
        fi

        virsh net-define ${networkXml}
        virsh net-autostart kali-network
        virsh net-start kali-network
        virsh define ${vmXml}
      '';
    };

    environment.systemPackages = with pkgs; [
      xorg.xauth
      qemu
      libvirt

      # debugging
      strace
      inetutils
      ethtool
      usbutils
    ];

    environment.variables = {
      LIBVIRT_DEFAULT_URI = "qemu:///system";
    };

    environment.interactiveShellInit = ''
      alias v=virt-manager
    '';
  };
}
