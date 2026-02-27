{
  pkgs,
  inputs,
  lib,
  secretsPath,
  ...
}: {
  # -----------------
  # | SPECIFICATION |
  # -----------------
  # Model: AMD Ryzen 9 9950X

  # --------------------------
  # | ROLES & MODULES & etc. |
  # --------------------------
  imports = with inputs; [
    hardware.nixosModules.common-cpu-amd
    hardware.nixosModules.common-gpu-amd
    # hardware.nixosModules.common-gpu
    hardware.nixosModules.common-pc-ssd
    home-manager.nixosModules.default
    disko.nixosModules.disko
    ./hardware-configuration.nix
    ./disko.nix
    ./net.nix
    ./modules
  ];

  topology.self.icon = "devices.desktop";
  # ------------------------------
  # | ADDITIONAL SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    openssl.dev
    openssl
    # inputs.ibkr-rust.packages.${pkgs.system}.flex
    libva-utils
    networkmanagerapplet # need this to configure L2TP ipsec
    wireguard-tools
    docker-compose
  ];
  virtualisation.podman.enable = true;
  users.users."czichy".extraGroups = ["docker"];

  # ----------------------------
  # | ADDITIONAL USER PACKAGES |
  # ----------------------------
  # home-manager.users.${user} = {home.packages = with pkgs; [];};

  # users.defaultUserShell = pkgs.fish;
  users.defaultUserShell = lib.mkForce pkgs.nushell;
  users.users."czichy".shell = lib.mkForce pkgs.nushell;

  # -------------------------------------------------------
  # | AUDIO: rtkit for real-time scheduling (PipeWire)    |
  # -------------------------------------------------------
  # Without rtkit, PipeWire threads run at normal priority and get
  # preempted under load (gaming, compilation, Docker) → buffer underruns,
  # dropouts, and eventually PipeWire daemon crashes.
  security.rtkit.enable = true;

  # -------------------------------------------------------
  # | AUDIO: Disable HDA & USB-audio kernel power-saving  |
  # -------------------------------------------------------
  # snd_hda_intel.power_save=0  → prevents pops/clicks when the onboard
  #   HDA codec wakes from its 1-second default idle timeout.
  # snd_usb_audio.quirks=...    → not needed here; udev rule below handles it.
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=0 power_save_controller=N
  '';

  services = {
    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      jack.enable = true;

      # ── PipeWire daemon tuning ─────────────────────────────────────
      # Raise the default quantum to 2048 samples (~42 ms at 48 kHz).
      # USB audio (especially the HECATE G1000 II) needs a larger buffer
      # to survive occasional xHCI scheduling jitter.  Applications that
      # need lower latency can still request it down to min.quantum.
      extraConfig.pipewire."92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 2048;
          "default.clock.min-quantum" = 1024;
          "default.clock.max-quantum" = 4096;
        };
      };

      # ── WirePlumber rules ──────────────────────────────────────────
      # Fix HECATE G1000 II: broken PCM dB range causes audio dropouts.
      # WirePlumber rule to use linear volume control instead of dB.
      # Applies to BOTH output AND input (microphone) nodes.
      wireplumber.extraConfig."51-hecate-g1000" = {
        "monitor.alsa.rules" = [
          # Output (speakers/headphones)
          {
            matches = [{"node.name" = "alsa_output.usb-_HECATE_G1000_II-00.analog-stereo";}];
            actions.update-props = {
              "api.alsa.soft-mixer" = true;
              "node.pause-on-idle" = false;
              "session.suspend-timeout-seconds" = 0;
            };
          }
          # Input (microphone) — same fix: broken dB range + prevent idle suspend
          {
            matches = [{"node.name" = "~alsa_input.usb-_HECATE_G1000_II-00.*";}];
            actions.update-props = {
              "api.alsa.soft-mixer" = true;
              "node.pause-on-idle" = false;
              "session.suspend-timeout-seconds" = 0;
            };
          }
        ];
      };

      # Globally disable node suspension so that no audio device sleeps
      # and triggers USB re-enumeration or HDA codec wake-up races.
      wireplumber.extraConfig."50-disable-suspend" = {
        "monitor.alsa.rules" = [
          {
            matches = [{"node.name" = "~alsa_*";}];
            actions.update-props = {
              "session.suspend-timeout-seconds" = 0;
            };
          }
        ];
      };
    };
    # udev.extraRules = "KERNEL==\"i2c-[0-9]*\", GROUP+=\"users\"";
    # Needed for gpg pinetry
    # pcscd.enable = true;
  };

  # HECATE G1000 II (USB VID:35bb PID:b0c8): disable USB autosuspend to
  # prevent audio dropouts when device briefly suspends between sounds.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="35bb", ATTRS{idProduct}=="b0c8", TEST=="power/control", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
  '';

  programs.nix-ld.enable = true;

  # Steam needs system-level integration for sandbox setuid wrappers,
  # firewall rules, and proper FHS environment (fixes launch from Walker/desktop)
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = with pkgs; [
      # --- Graphics / Vulkan / Mesa ---
      # Fixes: "Unable to determine architecture of provider" and
      # "drirc.d is unlikely to appear in /run/host" by making the
      # Vulkan ICD loader, Mesa DRI configs, and DRM libs available
      # inside pressure-vessel's container runtime.
      vulkan-loader
      mesa
      libdrm

      # --- X11 runtime libs ---
      libxrandr
      libxcomposite
      libxdamage
      libxfixes
      libxtst
      libxcursor
      libxi
      libxinerama
      libxscrnsaver

      # --- Audio ---
      libpulseaudio
      libvorbis

      # --- General runtime libs ---
      libpng
      stdenv.cc.cc.lib
      libkrb5
      keyutils

      # --- Gaming tools ---
      gamescope
      mangohud
      gamemode
    ];
  };

  home-manager.users."czichy" = import (../../homes + "/czichy@desktop");

  # users.users.qemu-libvirtd.group = "qemu-libvirtd";
  # users.groups.qemu-libvirtd = {};

  security.pam.services = {
    swaylock = {};
  };
}
