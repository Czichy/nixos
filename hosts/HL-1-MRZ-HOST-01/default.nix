{
  pkgs,
  lib,
  inputs,
  ...
}: {
  # -----------------
  # | SPECIFICATION |
  # -----------------
  # Model: Lenovo B51-80

  # --------------------------
  # | ROLES & MODULES & etc. |
  # --------------------------
  imports = with inputs; [
    home-manager.nixosModules.default
    disko.nixosModules.disko
    ../../modules/globals.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
    ./guests.nix
    ./modules
  ];

  # topology.self.hardware.image = ../../topology/images/Topton.webp;
  topology.self.hardware.info = "AMD Ryzen (Matisse), 64GB RAM, GTX 1660 SUPER";
  # |----------------------------------------------------------------------| #
  # | ADDITIONAL SYSTEM PACKAGES |
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    pkg-config
    pciutils # A collection of programs for inspecting and manipulating configuration of PCI devices
    usbutils # Tools for working with USB devices, such as lsusb
    minicom # Modem control and terminal emulation program
    inputs.power-meter.packages.${pkgs.stdenv.hostPlatform.system}.power-meter
  ];
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];
  # |----------------------------------------------------------------------| #

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  users.defaultUserShell = pkgs.nushell;
  # users.defaultUserShell = pkgs.fish;

  # If you intend to route all your traffic through the wireguard tunnel, the
  # default configuration of the NixOS firewall will block the traffic because
  # of rpfilter. You can either disable rpfilter altogether:
  networking.firewall.checkReversePath = false;

  home-manager.users."czichy" = import (../../homes + "/czichy@server");
  users.users.qemu-libvirtd.group = "qemu-libvirtd";
  users.groups.qemu-libvirtd = {};

  # Workaround: microvm.nix supervisord event buffer overflow.
  # edu-search has 10+ virtiofs shares → 11 supervisord processes.
  # The default event buffer_size (10) overflows, the notify handler
  # misses RUNNING events and never sends sd_notify(READY=1) → timeout.
  # Fix: wrap ExecStart with a script that starts supervisord in the
  # background, polls for all virtiofs sockets, sends sd_notify(READY=1),
  # then waits for supervisord to exit.
  systemd.services."microvm-virtiofsd@edu-search".serviceConfig.ExecStart = let
    stateDir = "/var/lib/microvms";
    originalRun = "${stateDir}/edu-search/current/bin/virtiofsd-run";
    wrapper = pkgs.writeShellScript "virtiofsd-run-wrapper" ''
      # Clean up stale sockets from previous runs
      rm -f ${stateDir}/edu-search/*.sock

      # Start the original virtiofsd-run (supervisord) in background
      ${originalRun} &
      SUPERVISORD_PID=$!

      # Wait for supervisord to create all 10 sockets
      # (9x HL-3-RZ-EDU-01-virtiofs-*.sock + journal.sock)
      EXPECTED=10
      for i in $(seq 1 120); do
        COUNT=0
        for sock in ${stateDir}/edu-search/*.sock; do
          [ -S "$sock" ] && COUNT=$((COUNT + 1))
        done
        if [ "$COUNT" -ge "$EXPECTED" ]; then
          ${pkgs.systemd}/bin/systemd-notify --ready
          # Wait for supervisord to exit (keeps service alive)
          wait $SUPERVISORD_PID
          exit $?
        fi
        sleep 0.5
      done
      echo "Timeout waiting for virtiofsd sockets (got $COUNT, expected $EXPECTED)" >&2
      kill $SUPERVISORD_PID 2>/dev/null
      exit 1
    '';
  in
    lib.mkForce ["" "${wrapper}"];

  # |----------------------------------------------------------------------| #
  systemd.tmpfiles.settings = {
    "10-var-lib-private" = {
      "/var/lib/private" = {
        d = {
          mode = "0700";
          user = "root";
          group = "root";
        };
      };
    };
  };
  # |----------------------------------------------------------------------| #

  security.pam.services = {
    swaylock = {};
  };
}
