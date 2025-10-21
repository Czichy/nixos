# Ausschnitt aus der Konfiguration Deines VPS (Externer Caddy Host)
{
  config,
  pkgs,
  ...
}: {
  # Stelle sicher, dass die Gruppe acme existiert
  users.groups.acme = {};
  users.groups.acme-sync = {};

  # 1. Benutzer "acme-sync" erstellen, falls noch nicht vorhanden
  users.users.acme-sync = {
    isSystemUser = true;
    extraGroups = ["acme"]; # Füge "acme" hinzu
    # optional: Shell deaktivieren für mehr Sicherheit
    shell = "${pkgs.bash}/bin/sh"; # Use /bin/sh or /bin/bash
  };

  # 2. Öffentlichen Schlüssel hinzufügen
  users.users.acme-sync.openssh.authorizedKeys.keys = [
    # Füge hier den gesamten INHALT der Datei ~/.ssh/id_sync_vps.pub ein (beginnt mit ssh-ed25519 ...)
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEclKRsUKJ9W0ARWNt5E6iu6tsX/jImzF3MvCdngS2dz acme-sync@intern-caddy"
  ];

  # 3. Berechtigungen für den Zertifikatspfad setzen
  # Der User acme-sync muss Leserechte auf die ACME-Zertifikate haben!
  systemd.tmpfiles.rules = [
    # Erlaube dem acme-sync Benutzer und der Gruppe, die Zertifikate zu lesen
    "d /var/lib/acme 0750 root acme-sync -"
    "Z /var/lib/acme/ vaul.czichy.com 0750 root acme-sync -" # spezifischer Pfad
    "z /var/lib/acme/vaul.czichy.com/fullchain.pem 0640 root acme-sync -"
    "z /var/lib/acme/vaul.czichy.com/key.pem 0640 root acme-sync -"
  ];

  # Optional: Wenn Du einen "key.pem" statt "key" hast, passe dies an

  # 4. SSH-Server aktivieren (sollte bereits der Fall sein)
  services.openssh.enable = true;
}
