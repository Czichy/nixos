{
  config,
  lib,
  pkgs,
  secretsPath,
  ...
}:
with builtins; let
  inherit
    (lib)
    genAttrs
    ;
  caddyLocalDomain = "caddy.czichy.com";

  acme-cfg = config.tensorfiles.services.networking.acme;
  caddyMetricsPort = 2019;

  syncKeyName = "id_sync_vps_key";
  vpsUserHost = "acme-sync@10.46.0.90";

  vpsCertPath = "/var/lib/acme/czichy.com/";
  localCertDir = "/var/lib/acme-sync/czichy.com";
  # Der Pfad, unter dem das Secret von NixOS im Dateisystem bereitgestellt wird
  # privateKeyPath = "/run/keys/sync/${syncKeyName}";
in {
  networking.hostName = "HL-3-DMZ-PROXY-01";
  # |----------------------------------------------------------------------| #
  networking.firewall.allowedTCPPorts = [
    80 # Caddy
    443 # Caddy
    caddyMetricsPort
  ];
  # |----------------------------------------------------------------------| #

  services.caddy = {
    enable = true;
    email = "christian@czichy.com";
    # On the back, the trusted_proxies global option is used to tell Caddy to trust the front instance as a proxy.
    # This ensures the real client IP is preserved.
    logFormat = ''
        output file /var/log/caddy/access.log {
      	roll_size 10mb
      	roll_keep 5
      	roll_keep_for 168h
      }
    '';
    globalConfig = ''
      servers {
      	trusted_proxies static private_ranges
      	trusted_proxies static 10.46.0.0/24
      }
    '';
    virtualHosts."localhost".extraConfig = ''
      respond "OK"
    '';

    extraConfig = ''
      (czichy_headers) {
        	header {
        		Permissions-Policy interest-cohort=()
        		Strict-Transport-Security "max-age=31536000; includeSubdomains"
        		X-XSS-Protection "1; mode=block"
        		X-Content-Type-Options "nosniff"
        		X-Robots-Tag noindex, nofollow
        		Referrer-Policy "same-origin"
        		Content-Security-Policy "frame-ancestors czichy.com *.czichy.com "
        		-Server
        		Permissions-Policy "geolocation=(self czichy.com *.czichy.com ), microphone=()"
        	}
        }
    '';
  };

  # |----------------------------------------------------------------------| #

  systemd.services.caddy = {
    serviceConfig = {
      # Required to use ports < 1024
      AmbientCapabilities = "cap_net_bind_service";
      CapabilityBoundingSet = "cap_net_bind_service";
      # Allow Caddy to read Cloudflare API key for DNS validation
      # EnvironmentFile = [
      #   config.age.secrets.caddy-cloudflare-token.path
      # ];
      TimeoutStartSec = "5m";
    };
  };
  # |----------------------------------------------------------------------| #
  # 1. Private Schlüsseldatei über Age einbinden
  # Du musst den Inhalt von ~/.ssh/id_sync_vps verschlüsselt in Deinem Flake-Repo ablegen.
  age.secrets.${syncKeyName} = {
    # Der Schlüssel wird unter /run/keys/sync/id_sync_vps_key abgelegt
    #
    file = secretsPath + "/hosts/HL-1-MRZ-HOST-02/acme-sync/id_sync_vps_key.age";
    # Wichtig: Lesbar für den root-Benutzer, der den systemd-Service ausführt
    owner = "root";
    group = "root";
    mode = "0400"; # Nur lesbar für root
  };

  # 2. Konfiguration des SSH-Clients
  programs.ssh = {
    # Stelle sicher, dass der Client die WireGuard-IP kennt (ansonsten wird das erste Mal nach Bestätigung gefragt)
    knownHosts = {
      "vps-wireguard" = {
        # Ersetze 10.10.0.1 durch die WireGuard-IP Deines VPS
        hostNames = ["10.46.0.90"];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAe95eSPkz/ASkZkfuXKtzufGdyI3s6d9Ms4ZuQaUXjs"; # Öffentlichen Schlüssel des VPS eintragen
      };
    };
  };

  # 3. Synchronisations-Service anpassen
  systemd.services.acme-cert-sync = {
    # ... (restliche Service-Definition aus der vorherigen Antwort) ...
    serviceConfig = {
      # Füge die private Schlüsseldatei als Identität hinzu
      ExecStart = ''
        ${pkgs.rsync}/bin/rsync -az \
          --include='*/' \
          --include='fullchain.pem' \
          --include='key.pem' \
          --exclude='*' \
          -e "${pkgs.openssh}/bin/ssh -i ${config.age.secrets.${syncKeyName}.path} -o StrictHostKeyChecking=yes" \
          ${vpsUserHost}:${vpsCertPath} \
          ${localCertDir}
      '';
      User = "root";
      # ...
    };
  };
  # 2. Systemd Timer zur regelmäßigen Ausführung (z.B. 1x wöchentlich)
  systemd.timers.acme-cert-sync = {
    description = "Run ACME cert sync weekly for internal Caddy";
    # Ziel, damit der Timer im System aktiviert wird
    wantedBy = ["timers.target"];
    timerConfig = {
      # Führe einmal wöchentlich aus (ideal nach der möglichen LE-Erneuerung)
      OnCalendar = "weekly";
      # Startet den Service direkt nach dem ersten Boot
      Persistent = true;
      # Der Timer startet den Service "acme-cert-sync.service"
    };
  };

  # 3. Notwendige Pakete
  environment.systemPackages = [pkgs.rsync];
  #
  # |----------------------------------------------------------------------| #
  system.stateVersion = "24.05";
}
