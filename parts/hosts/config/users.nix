{
  users.deterministicIds = let
    uidGid = id: {
      uid = id;
      gid = id;
    };
  in {
    acme = uidGid 991;
    fwupd-refresh = uidGid 979;
    git = uidGid 983;
    grafana = uidGid 992;
    influxdb2 = uidGid 986;
    kanidm = uidGid 990;
    loki = uidGid 989;
    maddy = uidGid 976;
    microvm = uidGid 994;
    minecraft = uidGid 975;
    msr = uidGid 980;
    netbird-home = uidGid 973;
    nixseparatedebuginfod = uidGid 981;
    nscd = uidGid 996;
    oauth2-proxy = uidGid 987;
    podman = uidGid 977;
    polkituser = uidGid 995;
    promtail = uidGid 993;
    radicale = uidGid 978;
    redis-paperless = uidGid 982;
    rtkit = uidGid 984;
    sshd = uidGid 997;
    stalwart-mail = uidGid 974;
    systemd-coredump = uidGid 998;
    systemd-oom = uidGid 999;
    telegraf = uidGid 985;
    vaultwarden = uidGid 988;
  };
}
