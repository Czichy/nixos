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
{
  localFlake,
  secretsPath,
  pubkeys,
  globals,
}: {
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit (localFlake.lib.tensorfiles) isModuleLoadedAndEnabled mkImpermanenceEnableOption;

  cfg = config.tensorfiles.services.virtualisation.microvm.adguardhome;

  # adguardhomeDomain = "adguardhome.czichy.com";
  # adguardhomeDomain = "adguardhome.${config.repo.secrets.global.domains.me}";

  # server = globals.net.home-lan.hosts.ward-adguardhome.ipv4;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.system.impermanence
    else {};
in {
  options.tensorfiles.services.virtualisation.microvm.adguardhome = with types; {
    enable = mkEnableOption ''
      Enables Micro-VM adguardhome.
    '';

    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      topology.self.services.adguardhome.info = "https://" + adguardhomeDomain;
      globals.services.adguardhome.domain = adguardhomeDomain;
      # tensorfiles.globals.monitoring.dns.adguardhome = {
      #   server = server;
      #   domain = ".";
      #   network = "home-lan";
      # };

      # wireguard.proxy-sentinel = {
      #     client.via = "sentinel";
      #     firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.adguardhome.port];
      #   };

      #   nodes.sentinel = {
      #     services.nginx = {
      #       upstreams.adguardhome = {
      #         servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.adguardhome.port}" = {};
      #         extraConfig = ''
      #           zone adguardhome 64k;
      #           keepalive 2;
      #         '';
      #         monitoring = {
      #           enable = true;
      #           expectedBodyRegex = "AdGuard Home";
      #         };
      #       };
      #       virtualHosts.${adguardhomeDomain} = {
      #         forceSSL = true;
      #         useACMEWildcardHost = true;
      #         oauth2.enable = true;
      #         oauth2.allowedGroups = ["access_adguardhome"];
      #         locations."/" = {
      #           proxyPass = "http://adguardhome";
      #           proxyWebsockets = true;
      #         };
      #       };
      #     };
      #   };
      microvm.vms.adguardhome = {
        autostart = true;
        restartIfChanged = true;

        specialArgs = {
          inherit localFlake;
          inherit secretsPath pubkeys;
          inherit globals;
        };

        config = {
          # imports = [import ../../networking/ssh.nix {inherit localFlake;}];

          microvm = {
            # Any other configuration for your MicroVM
            mem = 1024; # RAM allocation in MB
            vcpu = 1; # Number of Virtual CPU cores
            # It is highly recommended to share the host's nix-store
            # with the VMs to prevent building huge images.
            # shares can not be set to `neededForBoot = true;`
            # so if you try to use a share in boot script(such as system.activationScripts), it will fail!
            shares = [
              {
                # It is highly recommended to share the host's nix-store
                # with the VMs to prevent building huge images.
                # a host's /nix/store will be picked up so that no
                # squashfs/erofs will be built for it.
                #
                # by this way, /nix/store is readonly in the VM,
                # and thus the VM can't run any command that modifies
                # the store. such as nix build, nix shell, etc...
                # if you want to run nix commands in the VM, see
                # https://github.com/astro/microvm.nix/blob/main/doc/src/shares.md#writable-nixstore-overlay
                tag = "ro-store"; # Unique virtiofs daemon tag
                proto = "virtiofs"; # virtiofs is faster than 9p
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              }
              {
                # On the host
                source = "/var/lib/microvms/${config.networking.hostName}/journal";
                # In the MicroVM
                mountPoint = "/var/log/journal";
                tag = "journal";
                proto = "virtiofs";
                socket = "journal.sock";
              }
            ];
            interfaces = [
              {
                type = "tap";
                id = "vm-adguardhome"; # should be prefixed with "vm-"
                mac = "02:00:00:00:00:08"; # Unique MAC address
              }
            ];

            # Block device images for persistent storage
            # microvm use tmpfs for root(/), so everything else
            # is ephemeral and will be lost on reboot.
            #
            # you can check this by running `df -Th` & `lsblk` in the VM.
            volumes = [
              {
                mountPoint = "/var";
                image = "var.img";
                size = 512;
              }
              {
                mountPoint = "/etc";
                image = "etc.img";
                size = 50;
              }
            ];
            hypervisor = "qemu";
            # Control socket for the Hypervisor so that a MicroVM can be shutdown cleanly
            socket = "control.socket";
            # specialArgs = {inherit localFlake config lib agenix private;};
          };
          users.users.root.password = "";
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfYUpuZeYCkKCNL22+jUBroV4gaZYJOjcRVPDZDVXSp root@desktop"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPMF0Sz9e6JoHudF11U2F9U/S5KFINlU9556C2zA82X czichy@vmtest"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHsXDsMxnu+pECq4+aJyBk59ASKbr8ENLGeb/ncrJ4T8 czichy@homeservertest"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKQgoSENg960XY9wU77q8p1+4WgUhEb10xlc27RWcmNE czichy@desktop"
            # sshPubKey
          ];

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          systemd.network.enable = true;

          # systemd.network.networks."20-lan" = {
          #   matchConfig.Type = "ether";
          #   networkConfig = {
          #     Address = [ipv4WithMask];
          #     Gateway = mainGateway;
          #     DNS = nameservers;
          #     DHCP = "no";
          #   };
          # };

          networking.firewall = {
            allowedTCPPorts = [53];
            allowedUDPPorts = [53];
          };

          services.adguardhome = {
            enable = true;
            mutableSettings = false;
            host = "0.0.0.0";
            port = 3000;
            settings = {
              dns = {
                # port = properties.ports.dns;
                # allowed_clients = [
                # ];
                #trusted_proxies = [];
                ratelimit = 300;
                upstream_dns = [
                  "https://dns.cloudflare.com/dns-query"
                  "https://dns.google/dns-query"
                  "https://doh.mullvad.net/dns-query"
                ];
                bootstrap_dns = [
                  "1.1.1.1"
                  # FIXME: enable ipv6 "2606:4700:4700::1111"
                  "8.8.8.8"
                  # FIXME: enable ipv6 "2001:4860:4860::8844"
                ];
                dhcp.enabled = false;
              };
              # filtering.rewrites =
              #   [
              #     # Undo the /etc/hosts entry so we don't answer with the internal
              #     # wireguard address for influxdb
              #     {
              #       inherit (globals.services.influxdb) domain;
              #       answer = config.repo.secrets.global.domains.me;
              #     }
              #   ]
              # Use the local mirror-proxy for some services (not necessary, just for speed)
              # ++
              # map (domain: {
              # inherit domain;
              # answer = globals.net.home-lan.hosts.ward-web-proxy.ipv4;
              # })
              #[
              #   # FIXME: dont hardcode, filter global service domains by internal state
              #   globals.services.grafana.domain
              #   globals.services.influxdb.domain
              #   globals.services.loki.domain
              #   "home.${config.repo.secrets.global.domains.me}"
              #   "fritzbox.${config.repo.secrets.global.domains.me}"
              # ]
              # ;
              filters = [
                {
                  name = "AdGuard DNS filter";
                  url = "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt";
                  enabled = true;
                  id = 1;
                }
                {
                  name = "AdAway Default Blocklist";
                  url = "https://adaway.org/hosts.txt";
                  enabled = true;
                  id = 2;
                }
                {
                  name = "OISD (Big)";
                  url = "https://big.oisd.nl";
                  enabled = true;
                  id = 3;
                }
                {
                  enabled = true;
                  url = "${filter-dir}/filter_12.txt";
                  name = "Dandelion Sprout's Anti-Malware List";
                  id = 4;
                }
              ];
            };
          };

          systemd.services.adguardhome = {
            preStart = lib.mkAfter ''
              INTERFACE_ADDR=$(${pkgs.iproute2}/bin/ip -family inet -brief addr show enp0s5 | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+") \
                ${lib.getExe pkgs.yq-go} -i '.dns.bind_hosts = [strenv(INTERFACE_ADDR)]' \
                "$STATE_DIRECTORY/AdGuardHome.yaml"
            '';
            serviceConfig.RestartSec = lib.mkForce "60"; # Retry every minute
          };

          system.stateVersion = "24.05";
        };
      };
    }
    # |----------------------------------------------------------------------| #

    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      environment.persistence."${impermanence.persistentRoot}" = {
        directories = ["/var/lib/private/AdGuardHome"];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.tensorfiles.maintainers; [czichy];
}
