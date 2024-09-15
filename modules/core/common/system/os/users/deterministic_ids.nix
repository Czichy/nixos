{
  users.deterministicIds = let
    uidGid = id: {
      uid = id;
      gid = id;
    };
  in {
    qemu-libvirtd = uidGid 901;
    messagebus = uidGid 904;
    polkituser = uidGid 928;
    cupy = uidGid 936;
    systemd-coredump = uidGid 951;
    systemd-network = uidGid 952;
    systemd-resolve = uidGid 953;
    systemd-timesync = uidGid 954;
    minecraft = uidGid 975;
    podman = uidGid 977;
    msr = uidGid 980;
    ntp = uidGid 982;
    git = uidGid 983;
    rtkit = uidGid 984;
    tcpcryptd = uidGid 985;
    gamemode = uidGid 986;
    oauth2-proxy = uidGid 987;
    tss = uidGid 988;
    greeter = uidGid 989;
    geoclue = uidGid 990;
    acme = uidGid 991;
    systemd-oom = uidGid 992;
    sshd = uidGid 993;
    nscd = uidGid 994;
    microvm = uidGid 995;
    fwupd-refresh = uidGid 996;
    flatpak = uidGid 997;
    btrbk = uidGid 998;
    avahi = uidGid 999;
  };
}
