authorizedKeys: _guestName: guestCfg: {
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkForce;
in {
  node.name = guestCfg.nodeName;

  networking.firewall.allowedTCPPorts = [22];
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
    settings.PasswordAuthentication = true;
    hostKeys = [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  fileSystems."/persist".neededForBoot = mkForce true;
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos" # contains user/group id map
      "/var/log"
    ];

    files = [
      "/etc/machine-id"
      "/root/.bash_history"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKQgoSENg960XY9wU77q8p1+4WgUhEb10xlc27RWcmNE czichy@desktop"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKAL9mtLn2ASGNkOsS38GXrLDNmLLedb0XNJzhOxtAB christian@czichy.com"
  ];

  services.resolved = {
    # Disable local DNS stub listener on 127.0.0.53
    extraConfig = ''
      DNSStubListener=no
    '';
  };

  nix = {
    settings.auto-optimise-store = mkForce false;
    optimise.automatic = mkForce false;
    gc.automatic = mkForce false;
  };

  environment.systemPackages = [pkgs.helix];

  systemd.network.enable = true;
  networking.useNetworkd = true;

  systemd.network.networks."10-${guestCfg.networking.mainLinkName}" = {
    matchConfig.Name = guestCfg.networking.mainLinkName;
    matchConfig.Mac = "";
    # matchConfig.Type = "ether";
    DHCP = "no";
    # XXX: Do we really want this?
    dhcpV4Config.UseDNS = false;
    dhcpV6Config.UseDNS = false;
    ipv6AcceptRAConfig.UseDNS = false;
    networkConfig = {
      Address = [guestCfg.networking.address];
      Gateway = guestCfg.networking.gateway;
      # DNS = guestCfg.networking.dns;
      IPv6PrivacyExtensions = "yes";
      MulticastDNS = true;
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };
}
