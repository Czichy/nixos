{
  config,
  globals,
  pkgs,
  lib,
  inputs,
  hostName,
  ...
}: let
  javaPort = 25565;
  bedrockPort = 19132;
in {
  # nix-minecraft NixOS-Modul + Overlay für minecraftServers.paper-*
  imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];

  # |----------------------------------------------------------------------| #
  microvm.mem = 1024 * 4; # 4 GB – ausreichend für 10 Spieler (JVM -Xmx3G)
  microvm.vcpu = 2;
  # |----------------------------------------------------------------------| #
  networking.hostName = hostName;
  tensorfiles.services.monitoring.node-exporter.enable = true;

  nixpkgs.overlays = [inputs.nix-minecraft.overlay];

  # |----------------------------------------------------------------------| #
  networking.firewall = {
    allowedTCPPorts = [javaPort];
    allowedUDPPorts = [bedrockPort]; # GeyserMC Bedrock-Listener
  };

  # |----------------------------------------------------------------------| #
  # Paper-Server mit GeyserMC (Java↔Bedrock-Bridge) + Floodgate (Xbox-Auth)
  # |----------------------------------------------------------------------| #
  services.minecraft-servers = {
    enable = true;
    eula = true;

    servers.main = {
      enable = true;
      # Neueste stabile Version in nix-minecraft (Stand März 2026)
      package = pkgs.minecraftServers.paper-1_21_8;

      # Aikar's Flags – optimiert für G1GC bei Minecraft
      jvmOpts = lib.concatStringsSep " " [
        "-Xms1G"
        "-Xmx3G"
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
      ];

      serverProperties = {
        server-port = javaPort;
        max-players = 10;
        motd = "czichy.com";
        difficulty = "normal";
        gamemode = "survival";
        online-mode = true;
        white-list = false;
        enable-rcon = false;
        # Benötigt für Floodgate (Bedrock-Spieler haben keine Java-Secure-Profile)
        enforce-secure-profile = false;
      };

      # Plugins als read-only Store-Symlinks einbinden.
      # GeyserMC schreibt seine Config beim ersten Start nach
      # /var/lib/minecraft/main/plugins/Geyser-Spigot/ (persistiert via ZFS).
      symlinks = {
        # GeyserMC 2.9.5 build 1101: übersetzt Bedrock↔Java-Protokoll
        "plugins/Geyser-Spigot.jar" = pkgs.fetchurl {
          url = "https://download.geysermc.org/v2/projects/geyser/versions/2.9.5/builds/1101/downloads/spigot";
          sha256 = "sha256-OdGTJW/8il6a2ugP+bssa+rjbQM0rRBAIGi+kD7FUfI=";
        };

        # Floodgate 2.2.5 build 130: Bedrock-Spieler per Xbox-Account (kein Java-Kauf nötig)
        "plugins/floodgate-spigot.jar" = pkgs.fetchurl {
          url = "https://download.geysermc.org/v2/projects/floodgate/versions/2.2.5/builds/130/downloads/spigot";
          sha256 = "sha256-LPTRZ+S+sU0xuyxewDZfgnd0dRLrC6f2vDHbyj2FCk4=";
        };

        # ViaVersion 5.7.2: erlaubt neuere Client-Protokolle (z.B. GeyserMC → 1.21.11)
        # auf einem älteren Paper-Server (1.21.8) zu verbinden
        "plugins/ViaVersion.jar" = pkgs.fetchurl {
          url = "https://github.com/ViaVersion/ViaVersion/releases/download/5.7.2/ViaVersion-5.7.2.jar";
          sha256 = "sha256-RDChJ/bLIdelLsagel3MQ7ojWswGLIYzBhm43h1JWP0=";
        };
      };
    };
  };

  # |----------------------------------------------------------------------| #
  # Persistenz: Welt, Plugins-Config, Ops etc. überleben Reboots
  environment.persistence."/persist" = {
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    directories = [
      {
        # nix-minecraft legt Serverdaten unter /var/lib/minecraft/<serverName> ab
        directory = "/var/lib/minecraft";
        user = "minecraft";
        group = "minecraft";
        mode = "0750";
      }
    ];
  };
  # |----------------------------------------------------------------------| #

  # Netzwerkzugang (intern + extern via OPNsense-Portweiterleitung):
  #
  #   DNS (OPNsense Unbound):
  #     mc.czichy.com → 10.15.40.32  (intern, split-DNS)
  #
  #   DNS (extern, z.B. Cloudflare):
  #     mc.czichy.com → <WAN-IP>
  #
  #   OPNsense NAT / Port Forward:
  #     WAN  TCP 25565 → 10.15.40.32:25565  (Java Edition)
  #     WAN  UDP 19132 → 10.15.40.32:19132  (Bedrock Edition via GeyserMC)
  #
  # Kein HTTP-Proxy (Caddy) nötig – Minecraft ist kein HTTP-Protokoll.
}
