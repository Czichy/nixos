{
  config,
  inputs,
  self,
  ...
}: let
  inherit (inputs.flake-parts.lib) importApply;
  inherit (self) secretsPath pubkeys;
  localFlake = self;
in {
  flake.nixosModules = {
    # -- misc --
    misc_nix = importApply ./misc/nix.nix {inherit inputs localFlake;};
    misc_node = importApply ./misc/node.nix {inherit inputs localFlake;};
    misc_distributed-config = importApply ./misc/distributed-config.nix {inherit inputs localFlake;};

    # -- profiles --
    profiles_base = importApply ./profiles/base.nix {inherit localFlake;};
    profiles_packages-extra = importApply ./profiles/packages-extra.nix {inherit localFlake inputs;};
    profiles_graphical-plasma6 = importApply ./profiles/graphical-plasma6.nix {
      inherit localFlake inputs;
    };
    profiles_graphical-hyprland = importApply ./profiles/graphical-hyprland.nix {
      inherit localFlake inputs;
    };
    profiles_graphical-startx-home-manager = importApply ./profiles/graphical-startx-home-manager.nix {
      inherit localFlake;
    };
    profiles_server = importApply ./profiles/server.nix {inherit localFlake;};
    profiles_headless = importApply ./profiles/headless.nix {inherit localFlake;};
    profiles_minimal = importApply ./profiles/minimal.nix {inherit localFlake;};

    # -- programs --

    # -- security --

    # -- services --
    # services_x11_desktop-managers_plasma6 = import ./services/x11/desktop-managers/plasma6.nix;
    services_flatpak = importApply ./services/flatpak.nix {inherit localFlake inputs;};
    services_printing = importApply ./services/printing.nix {inherit localFlake;};
    services_syncthing = importApply ./services/syncthing.nix {
      inherit localFlake;
      inherit secretsPath;
    };

    services_networking_networkmanager = importApply ./services/networking/networkmanager.nix {
      inherit localFlake;
    };
    services_networking_networkd = importApply ./services/networking/networkd.nix {inherit localFlake;};
    services_networking_ssh = importApply ./services/networking/ssh.nix {inherit localFlake;};
    services_networking_wireguard = importApply ./services/networking/wireguard.nix {
      inherit localFlake;
      inherit secretsPath;
    };
    services_nginx = importApply ./services/networking/nginx.nix {
      inherit localFlake;
      inherit secretsPath;
    };

    services_acme = importApply ./services/networking/acme.nix {
      inherit localFlake;
      inherit secretsPath;
    };

    services_x11_desktop-managers_startx-home-manager =
      importApply ./services/x11/desktop-managers/startx-home-manager.nix
      {inherit localFlake;};

    services_virtualisation = importApply ./services/virtualisation {inherit localFlake;};
    # -- micro vm --
    # services_microvm-host = importApply ./services/virtualisation/microvm-host.nix {inherit localFlake;};
    services_microvm = importApply ./services/microvm {
      inherit localFlake;
      inherit (config.secrets) pubkeys;
    };
    # -- system --
    system_initrd-ssh = importApply ./system/initrd-ssh.nix {
      inherit localFlake;
      inherit pubkeys;
    };
    system_impermanence = importApply ./system/impermanence.nix {inherit localFlake inputs;};
    system_users = importApply ./system/users {
      inherit localFlake;
      inherit secretsPath pubkeys;
    };
    system_zfs = importApply ./system/zfs.nix {inherit localFlake;};

    # -- tasks --
    tasks_nix-garbage-collect = importApply ./tasks/nix-garbage-collect.nix {inherit localFlake;};
    tasks_system-autoupgrade = importApply ./tasks/system-autoupgrade.nix {inherit localFlake;};
  };
}
