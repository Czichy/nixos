{
  inputs,
  lib,
  globals,
  pkgs,
  hostName,
  ...
}: let
  mcDomain = "mc.czichy.com";
  certloc = "/var/lib/acme/czichy.com";
  sharedMinecraftConfig = import ./minecraft/sharedMinecraftConfig.nix {inherit pkgs lib;};

  geyserUrl = n: v: b: "https://download.geysermc.org/v2/projects/${n}/versions/${v}/builds/${b}/downloads/velocity";
in
  with lib;
  with pkgs; {
    # |----------------------------------------------------------------------| #
    microvm.mem = 1024 * 4;
    microvm.vcpu = 4;
    # |----------------------------------------------------------------------| #
    networking.hostName = hostName;
    globals.services.unifi.domain = unifiDomain;
    nixpkgs.overlays = [inputs.nix-minecraft.overlay];
    imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
    # |----------------------------------------------------------------------| #

    networking.firewall = {
      allowedTCPPorts = [25565];
      allowedUDPPorts = [25565 19132];
    };

    nodes.HL-1-MRZ-HOST-02-caddy = {
      services.caddy = {
        virtualHosts."${mcDomain}".extraConfig = ''
          reverse_proxy http://${globals.net.vlan40.hosts."HL-3-RZ-MC-01".ipv4}:8443
          tls ${certloc}/cert.pem ${certloc}/key.pem {
             protocols tls1.3
          }
          import czichy_headers
        '';
      };
    };

    # |----------------------------------------------------------------------| #
    environment.persistence."/persist" = {
      files = [
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
      directories = [
        {
          directory = "/var/lib/minecraft-servers";
          mode = "0700";
        }
      ];
    };

    # |----------------------------------------------------------------------| #
    services.minecraft-servers = {
      enable = true;
      eula = true;
      dataDir = "/persist/data/minecraft-servers";
      servers = {
        hacko =
          mkMerge
          [
            sharedMinecraftConfig
            {
              serverProperties = {
                motd = "Welkom bij hacko!";
              };
            }
          ];
        gosigBeta = {
          enable = true;
          autoStart = false;
          package =
            callPackage
            stdenvNoCC.mkDerivation
            {
              pname = "minecraft-server";
              version = "b1.7.3";

              src = "${(fetchurl {
                url = "https://files.betacraft.uk/server-archive/beta/b1.7.3.jar";
                sha1 = "2F90DC1CB5CA7E9D71786801B307390A67FCF954";
              })}";

              preferLocalBuild = true;

              installPhase = ''
                mkdir -p $out/bin $out/lib/minecraft
                cp -v $src $out/lib/minecraft/server.jar

                cat > $out/bin/minecraft-server << EOF
                #!/bin/sh
                exec ${jre8_headless}/bin/java \$@ -jar $out/lib/minecraft/server.jar nogui
                EOF

                chmod +x $out/bin/minecraft-server
              '';

              dontUnpack = true;

              passthru = {
                tests = {inherit (nixosTests) minecraft-server;};
                updateScript = ./update.py;
              };

              meta = with lib; {
                description = "Minecraft Server";
                homepage = "https://minecraft.net";
                license = licenses.unfreeRedistributable;
                platforms = platforms.unix;
                maintainers = with maintainers; [infinidoge];
                mainProgram = "minecraft-server";
              };
            };
          jvmOpts = ((import ./minecraft/aikar-flags.nix) "4G") + " -Dhttp.proxyHost=betacraft.uk";
          serverProperties = {
            server-port = 25565;
            online-mode = false;
            motd = "Gosig beta!";
          };
        };
      };
    };
    # |----------------------------------------------------------------------| #

    services.minecraft-servers.servers.proxy = {
      symlinks = {
        "plugins/Geyser.jar" = pkgs.fetchurl rec {
          pname = "geyser";
          version = "2.2.2";
          url = geyserUrl pname version "427";
          hash = "sha256-vGrENEZfOjh8FLYVDyX9/lXwkR+0lAsEafV/F0F+4hk=";
        };
        "plugins/Floodgate.jar" = pkgs.fetchurl rec {
          pname = "floodgate";
          version = "2.2.2";
          url = geyserUrl pname version "90";
          hash = "sha256-v7Gfwl870Vy6Q8PcBETFKknVL5UVEWbGmCiw4MVR7XE=";
        };
      };
      files = {
        "plugins/Geyser-Velocity/config.yml".value = {
          server-name = "Server do Gabs";
          passthrough-motd = true;
          passthrough-player-counts = true;
          allow-third-party-capes = true;
          auth-type = "floodgate";
        };
      };
    };
  }
