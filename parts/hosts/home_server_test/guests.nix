{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  networking.nftables = {
    stopRuleset = lib.mkDefault ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;
          ct state invalid drop
          ct state {established, related} accept

          iifname lo accept
          meta l4proto ipv6-icmp accept
          meta l4proto icmp accept
          tcp dport ${toString (lib.head config.services.openssh.ports)} accept
          tcp dport 80 accept
          tcp dport 443 accept
        }
        chain forward {
          type filter hook forward priority filter; policy drop;
        }
        chain output {
          type filter hook output priority filter; policy accept;
        }
      }
    '';

    firewall = {
      enable = false;
      localZoneName = "local";
      snippets = {
        nnf-common.enable = false;
        nnf-conntrack.enable = true;
        nnf-drop.enable = true;
        nnf-loopback.enable = true;
        nnf-ssh.enable = true;
        nnf-icmp = {
          enable = true;
          ipv6Types = [
            "echo-request"
            "destination-unreachable"
            "packet-too-big"
            "time-exceeded"
            "parameter-problem"
            "nd-router-advert"
            "nd-neighbor-solicit"
            "nd-neighbor-advert"
          ];
          ipv4Types = [
            "echo-request"
            "destination-unreachable"
            "router-advertisement"
            "time-exceeded"
            "parameter-problem"
          ];
        };
      };
      rules.lan-to-local = {
        from = ["lan"];
        to = ["local"];

        inherit
          (config.networking.firewall)
          allowedTCPPorts
          allowedTCPPortRanges
          allowedUDPPorts
          allowedUDPPortRanges
          ;
      };

      # specific
      zones = {
        #untrusted.interfaces = [ ];
        lan.interfaces = [
          "brmgmt9"
          "brprim4"
          "brdata11"
        ];
      };
    };
  };
  tensorfiles.services.microvm = {
    enable = true;
    guests = let
      mkGuest = guestName: {enableStorageDataset ? false, ...}: {
        autostart = true;
        # temporary state that is wiped on reboot
        zfs."/state" = {
          pool = "rpool";
          dataset = "rpool/encrypted/vms/${guestName}";
        };
        # persistent state
        zfs."/persist" = {
          pool = "rpool";
          dataset = "rpool/encrypted/safe/vms/${guestName}";
        };
        modules = [
          ./guests/${guestName}.nix
          {
            #node.secretsDir = ./secrets/${guestName};
            networking.nftables.firewall = {
              zones.untrusted.interfaces = [
                config.tensorfiles.services.microvm.guests.${guestName}.networking.mainLinkName
              ];
            };
          }
        ];
        networking = config.repo.secrets.home-ops.guests.${guestName}.networking;
      };
      mkMicrovm = guestName: opts: {
        ${guestName} =
          mkGuest guestName opts
          // {
            microvm = {
              system = "x86_64-linux";
              macvtap = "brprim4";
              baseMac = "1c:69:7a:00:00:00"; # TODO move to config
            };
            extraSpecialArgs = {
              #inherit (inputs.self) nodes globals;
              #inherit (inputs.self.pkgs.x86_64-linux) lib;
              inherit lib;
              inherit inputs;
            };
          };
      };
    in ({} // mkMicrovm "hello-world" {enableStorageDataset = true;});
  };
}
