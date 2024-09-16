{pubkeys, ...}: let
  sshOpts = ''command="nix-daemon --stdio",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding'';
  mkBuilderKeys = keys: map (key: ''${sshOpts} ${key}'') pubkeys;
in {
  users = {
    groups.builder = {};
    users.builder = {
      useDefaultShell = false;
      isSystemUser = true;
      createHome = true;
      group = "builder";
      home = "/var/empty";
      openssh.authorizedKeys.keys = mkBuilderKeys [pubkeys.users.czichy];
    };
  };
}
