{
  pkgs,
  lib,
}: {
  enable = true;
  autoStart = true;
  package = pkgs.minecraftServers.paper-1_20_4;
  jvmOpts = (import ./aikar-flags.nix) "4G";
  serverProperties = {
    server-port = 25565;
    online-mode = true;
    enable-command-block = true;
    enforce-secure-profile = false;
  };
  files = {
    # "plugins/LuckPerms/config.yml" = lib'.toYAMLFile {
    #   split-storage = {
    #     # Don't touch this if you don't want to use split storage!
    #     enabled = true;
    #     methods = {
    #       # These options don't need to be modified if split storage isn't enabled.
    #       user = "h2";
    #       group = "h2";
    #       track = "h2";
    #       uuid = "h2";
    #       log = "h2";
    #     };
    #   };
    # };
  };
  # update with haskellPackages.update-nix-fetchgit
  symlinks = with pkgs; {
    # "plugins/FastAsyncWorldEdit.jar" = fetchurl {
    #   url = "https://github.com/IntellectualSites/FastAsyncWorldEdit/releases/download/2.9.0/FastAsyncWorldEdit-Bukkit-2.9.0.jar";
    #   sha256 = "1wy44937qy74drw5ifm6z0s0j2xg75l0z08vv3ffjxmg599km1pm";
    # };
    # "plugins/EssentialsX.jar" = fetchurl {
    #   url = "https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsX-2.20.1.jar";
    #   sha256 = "0hpm3fk073f2z8aah9l1inq27h9kd60jb2c1grcs8326v85s6bl0";
    # };
    # "plugins/EssentialsXChat.jar" = fetchurl {
    #   url = "https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsXChat-2.20.1.jar";
    #   sha256 = "19jwfymqgvjk0vkm1blhq2q6gi7jkgqznp6bxc3k1sqw4hh5raj0";
    # };
    # "plugins/EssentialsXSpawn.jar" = fetchurl {
    #   url = "https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsXSpawn-2.20.1.jar";
    #   sha256 = "1831sadiprzln6r8bvws5jbkvrr8xw6p3sx4zz2h4nl66dm7q3b5";
    # };
    # "plugins/DecentHolograms.jar" = fetchurl {
    #   url = "https://github.com/DecentSoftware-eu/DecentHolograms/releases/download/2.8.6/DecentHolograms-2.8.6.jar";
    #   sha256 = "15ikmg8qjzn8czf2x1m8nl04870ijd8i8i1y737g3wb7gz8c3rxh";
    # };
    # "plugins/CleanroomGenerator.jar" = fetchurl {
    #   url = "https://mediafilez.forgecdn.net/files/3596/715/CleanroomGenerator-1.2.1.jar";
    #   sha256 = "1wpk9hmyjc71jqnzdcinh5jrn2c3ijcnfmh8r5fq1mgnv3zbxla0";
    # };
    # "plugins/Geyser-Spigot.jar" = fetchurl {
    #   url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/434/downloads/spigot";
    #   sha256 = "13q3qw4wa4xya5m0r77advp331zkag96f2zsm35jjhlswlmjwjyh";
    # };
    # "plugins/Floodgate-Spigot.jar" = fetchurl {
    #   url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/96/downloads/spigot";
    #   sha256 = "1wamdq36j358jks3kq9rq93npxskfhddv5dqqkf6f6b4l9k4mjja";
    # };
    # "plugins/HeadDB.jar" = fetchurl {
    #   url = "https://github.com/TheSilentPro/HeadDB/releases/download/5.0.0-rc.10/HeadDB.jar";
    #   sha256 = "0fnravxnq77l5mr9likms1hg7vy001ymxr4h3vp16jnps21hvqx2";
    # };
    # "plugins/Multiverse-Core.jar" = fetchurl {
    #   url = "https://ci.onarandombox.com/view/Multiverse/job/Multiverse-Core/870/artifact/target/Multiverse-Core-4.3.2-SNAPSHOT.jar";
    #   sha256 = "1bdfjk956zn7fg7r0i8i4jm7l274dbc300rrvgny33hx6i9cprhw";
    # };
    # "plugins/Multiverse-Inventories.jar" = fetchurl {
    #   url = "https://ci.onarandombox.com/view/Multiverse/job/Multiverse-Inventories/524/artifact/target/Multiverse-Inventories-4.2.4-SNAPSHOT.jar";
    #   sha256 = "1n2vz65wkd9zl7faya4i4djnyf5qq2csvv3l9fsx9adqixki3pf9";
    # };
    # "plugins/Multiverse-SignPortals.jar" = fetchurl {
    #   url = "https://ci.onarandombox.com/view/Multiverse/job/Multiverse-SignPortals/771/artifact/target/Multiverse-SignPortals-4.2.1-SNAPSHOT.jar";
    #   sha256 = "0h28l8d4zg1w03vcaxgafij83bjdz1bk4mnh5zxmrwnjsykk6xwq";
    # };
    # "plugins/Multiverse-NetherPortals.jar" = fetchurl {
    #   url = "https://ci.onarandombox.com/view/Multiverse/job/Multiverse-NetherPortals/808/artifact/target/Multiverse-NetherPortals-4.2.3-SNAPSHOT.jar";
    #   sha256 = "011hbw2dp15ylkr5zk7g2ab4yg5g8szifx60p79c9v6l79xy4bnp";
    # };
    # "plugins/Vault.jar" = fetchurl {
    #   url = "https://github.com/MilkBowl/Vault/releases/download/1.7.3/Vault.jar";
    #   sha256 = "07fhfz7ycdlbmxsri11z02ywkby54g6wi9q0myxzap1syjbyvdd6";
    # };
    # "plugins/LuckPerms.jar" = fetchurl {
    #   url = "https://download.luckperms.net/1568/bukkit/loader/LuckPerms-Bukkit-5.4.151.jar";
    #   sha256 = "sha256-vOT1XvFhUFTwTWajItvKyAmvcgMK0M/bneMaL+stlX4=";
    # };
  };
}
