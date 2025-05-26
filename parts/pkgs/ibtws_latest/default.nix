{
  pkgs ? import <nixpkgs>,
  stdenv,
  lib,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  libXxf86vm,
  libX11,
  libXext,
  libXtst,
  libXi,
  libXrender,
  glib,
  libxml2,
  ffmpeg,
  libGL,
  freetype,
  fontconfig,
  gtk3,
  pango,
  cairo,
  alsa-lib,
  atk,
  gdk-pixbuf,
}:
with pkgs; let
  jdkWithJavaFX = pkgs.jdk23.override {
    enableJavaFX = true;
    openjfx23 = openjfx.override {withWebKit = true;};
  };
  ibDerivation = stdenv.mkDerivation rec {
    version = "10.37.1g";
    pname = "ib-tws-latest";

    src = fetchurl {
      url = "https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh";
      sha256 = "0kgpaic9ncd1qms3a841dhl3l1ijkni8xsb88da4dl5vrrq4cg5j";
      executable = true;
    };

    # Only build locally for license reasons.
    preferLocalBuild = true;

    phases = ["installPhase"];

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      # We use an installer FHS environment because the shell script unpacks
      # a binary, and immediately calls that binary. There is little hope
      # for us to patchelf ld-linux in between. An FHS env is easier.
      ${buildFHSEnvChroot {
        name = "fhs";
        targetPkgs = pkgs1: [
          libz
        ];
      }}/bin/fhs ${src} -q -dir $out/libexec

      # The following disables the JRE compatability check inside the tws script
      # so that we can use Oracle JRE pkgs of nixpkgs.
      sed -i 's#test_jvm "$INSTALL4J_JAVA_HOME_OVERRIDE"#app_java_home="$INSTALL4J_JAVA_HOME_OVERRIDE"#' $out/libexec/tws

      # Make the tws launcher script read $HOME/.tws/tws.vmoptions
      # instead of the unmutable version in $out.
      sed -i -e 's#read_vmoptions "$prg_dir/$progname.vmoptions"#read_vmoptions "$HOME/.tws/$progname.vmoptions"#' $out/libexec/tws

      # We set a bunch of flags found in the Arch PKGBUILD. The flags
      # releated to AA fonts seem to make a positive difference.
      # -Dawt.useSystemAAFontSettings=lcd or -Dawt.useSystemAAFontSettings=on
      # -Dsun.java2d.xrender=True not applied. Results in WARNING: The version of libXrender.so cannot be detected.
      # -Dsun.java2d.opengl=False not applied. Why would I disable that?
      # -Dswing.aatext=true applied
      mkdir $out/bin
      sed -e s#__OUT__#$out# -e s#__JAVAHOME__#${jdkWithJavaFX.home}# -e s#__GTK__#${pkgs.gtk3}# -e s#__CCLIBS__#${pkgs.stdenv.cc.cc.lib}# ${./tws-wrap.sh} > $out/bin/ib-tws-latest

      chmod a+rx $out/bin/ib-tws-latest

      # FIXME Fixup .desktop starter.
    '';

    meta = with lib; {
      description = "Trader Work Station of Interactive Brokers";
      homepage = "https://www.interactivebrokers.com";
      license = licenses.unfree;
      maintainers = [maintainers.clefru];
      platforms = platforms.linux;
    };
  };
  # IB TWS packages the JxBrowser component. It unpacks a prelatest
  # Chromium binary (yikes!) that needs an FHS environment. For me, that
  # doesn't yet work, and the chromium fails to launch with an error
  # code.
in
  buildFHSUserEnv {
    name = "ib-tws-latest";
    targetPkgs = pkgs1: [
      ibDerivation

      # Chromium dependencies. This might be incomplete.
      xorg.libXfixes
      alsa-lib
      xorg.libXcomposite
      cairo
      xorg.libxcb
      pango
      glib
      atk
      at-spi2-core
      at-spi2-atk
      xorg.libXext
      libdrm
      nspr
      #xorg.libxkbcommon
      nss
      cups
      mesa
      expat
      dbus
      xorg.libXdamage
      xorg.libXrandr
      xorg.libX11
      xorg.libxshmfence
      libxkbcommon
      systemd # for libudev.so.1
      stdenv.cc
      stdenv.cc.libc
      glib
      libxml2
      ffmpeg
      libGL
      libXxf86vm
      libGL
      alsa-lib
      fontconfig
      freetype
      pango
      gtk3
      cairo
      gdk-pixbuf
      atk
      libX11
      libXext
      libXtst
      libXi
      libXrender
    ];
    runScript = "env GDK_BACKEND=x11 /usr/bin/ib-tws-latest";
  }
# {
#   stdenv,
#   lib,
#   fetchurl,
#   patchelf,
#   makeDesktopItem,
#   copyDesktopItems,
#   libXxf86vm,
#   libX11,
#   libXext,
#   libXtst,
#   libXi,
#   libXrender,
#   glib,
#   libxml2,
#   ffmpeg,
#   libGL,
#   freetype,
#   fontconfig,
#   gtk3,
#   pango,
#   cairo,
#   alsa-lib,
#   atk,
#   gdk-pixbuf,
# }: let
#   rSubPaths = [
#     "lib/amd64/jli"
#     "lib/amd64/server"
#     "lib/amd64"
#   ];
# in
#   stdenv.mkDerivation rec {
#     pname = "ib-tws";
#     version = "10.34.1c";
#     etagHash = "28ba9461d0de56b53efc7a4106389df5";
#     src = fetchurl {
#       url = "https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh";
#       hash = "sha256-bpFKD1l8PwAV2g7MjApg3QC0TAO76VPHLiI5rGcfcSs=";
#     };
#     phases = ["unpackPhase" "installPhase" "fixupPhase"];
#     nativeBuildInputs = [copyDesktopItems];
#     desktopItems = [
#       (makeDesktopItem {
#         name = pname;
#         desktopName = "IB Trader Workstation";
#         exec = pname;
#         icon = pname;
#         categories = ["Office" "Finance"];
#         startupWMClass = "jclient-LoginFrame";
#       })
#       (makeDesktopItem {
#         name = "ib-gw";
#         desktopName = "IB Gateway";
#         exec = "ib-gw";
#         icon = pname;
#         categories = ["Office" "Finance"];
#         startupWMClass = "ibgateway-GWClient";
#       })
#     ];
#     unpackPhase = ''
#       echo "Unpacking I4J sfx sh to $PWD..."
#       INSTALL4J_TEMP="$PWD" sh "$src" __i4j_extract_and_exit
#       # JRE
#       jrePath="$out/share/${pname}/jre"
#       echo "Unpacking JRE to $jrePath..."
#       mkdir -p "$jrePath"
#       tar -xf "$PWD/"*.dir/jre.tar.gz -C "$jrePath/"
#       echo "Patching JRE executables..."
#       patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
#         "$jrePath/bin/java" "$jrePath/bin/unpack200"
#       echo "Unpacking JRE pack files..."
#       for f in "$jrePath/lib/"*.jar.pack "$jrePath/lib/ext/"*.jar.pack; do
#         jar_file=`echo "$f" | awk '{ print substr($0,1,length($0)-5) }'`
#         "$jrePath/bin/unpack200" -r "$f" "$jar_file"
#         [ $? -ne 0 ] && echo "Error unpacking $f" && exit 1
#       done
#       echo "Unpacking TWS payload..."
#       INSTALL4J_JAVA_HOME_OVERRIDE="$jrePath" sh "$src" -q -dir "$PWD/"
#     '';
#     installPhase = ''
#       runHook preInstall
#       # create main startup script
#       mkdir -p "$out/bin"
#       cat<<EOF > "$out/bin/${pname}"
#       #!$SHELL
#       # get script name
#       PROG=\$(basename "\$0")
#       # Load system-wide settings and per-user overrides
#       IB_CONFIG_DIR="\$HOME/.\$PROG"
#       JAVA_GC="-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70"
#       JAVA_UI_FLAGS="-Dswing.aatext=TRUE -Dawt.useSystemAAFontSettings=on -Dsun.awt.nopixfmt=true -Dsun.java2d.noddraw=true -Dswing.boldMetal=false -Dsun.locale.formatasdefault=true"
#       JAVA_LOCALE_FLAGS="-Dsun.locale.formatasdefault=true"
#       JAVA_FLAGS="\$JAVA_GC \$JAVA_UI_FLAGS \$JAVA_LOCALE_FLAGS \$JAVA_EXTRA_FLAGS"
#       [ -f "\$HOME/.config/\$PROG.conf" ] && . "\$HOME/.config/\$PROG.conf"
#       CLASS="jclient.LoginFrame"
#       [ "\$PROG" = "ib-gw" ] && CLASS="ibgateway.GWClient"
#       cd "$out/share/${pname}/jars"
#       "$out/share/${pname}/jre/bin/java" -cp \* \$JAVA_FLAGS \$CLASS \$IB_CONFIG_DIR
#       EOF
#       chmod u+x $out/bin/${pname}
#       # create symlink for the gateway
#       ln -s "${pname}" "$out/bin/ib-gw"
#       # copy files
#       mkdir -p $out/share/${pname}
#       cp -R jars $out/share/${pname}
#       install -Dm644 .install4j/tws.png $out/share/pixmaps/${pname}.png
#       runHook postInstall
#     '';
#     dontPatchELF = true;
#     dontStrip = true;
#     postFixup = ''
#       rpath+="''${rpath:+:}${lib.concatStringsSep ":" (map (a: "$jrePath/${a}") rSubPaths)}"
#       # set all the dynamic linkers
#       find $out -type f -perm -0100 \
#         -exec patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
#         --set-rpath "$rpath" {} \;
#       find $out -name "*.so" -exec patchelf --set-rpath "$rpath" {} \;
#     '';
#     rpath = lib.strings.makeLibraryPath libraries;
#     libraries = [
#       stdenv.cc
#       stdenv.cc.libc
#       glib
#       libxml2
#       ffmpeg
#       libGL
#       libXxf86vm
#       alsa-lib
#       fontconfig
#       freetype
#       pango
#       gtk3
#       cairo
#       gdk-pixbuf
#       atk
#       libX11
#       libXext
#       libXtst
#       libXi
#       libXrender
#     ];
#     # possibly missing libgdk-x11-2.0.so.0, from gtk2? never caused any trouble though
#     passthru.updateScript = ./update.sh;
#     meta = with lib; {
#       description = "Trader Work Station of Interactive Brokers";
#       homepage = "https://www.interactivebrokers.com";
#       license = licenses.unfree;
#       maintainers = lib.optionals (maintainers ? k3a) [maintainers.k3a];
#       platforms = ["x86_64-linux"];
#     };
#   }
# {
#   stdenv,
#   lib,
#   fetchurl,
#   makeDesktopItem,
#   copyDesktopItems,
#   libXxf86vm,
#   libX11,
#   libXext,
#   libXtst,
#   libXi,
#   libXrender,
#   glib,
#   libxml2,
#   ffmpeg,
#   libGL,
#   freetype,
#   fontconfig,
#   gtk3,
#   pango,
#   cairo,
#   alsa-lib,
#   atk,
#   gdk-pixbuf,
# }: let
#   rSubPaths = [
#     "lib/amd64/jli"
#     "lib/amd64/server"
#     "lib/amd64"
#   ];
# in
#   stdenv.mkDerivation rec {
#     pname = "ib-tws-native-latest";
#     version = "10.34.1c";
#     etagHash = "681ec81d65bd41af93981b120988c385";
#     src = fetchurl {
#       url = "https://download2.interactivebrokers.com/installers/tws/latest-standalone/tws-latest-standalone-linux-x64.sh";
#       hash = "sha256-bpFKD1l8PwAV2g7MjApg3QC0TAO76VPHLiI5rGcfcSs=";
#     };
#     phases = [
#       "unpackPhase"
#       "installPhase"
#       "fixupPhase"
#     ];
#     nativeBuildInputs = [copyDesktopItems];
#     desktopItems = [
#       (makeDesktopItem {
#         name = pname;
#         desktopName = "IB Trader Workstation - Latest";
#         exec = pname;
#         icon = pname;
#         categories = [
#           "Office"
#           "Finance"
#         ];
#         startupWMClass = "jclient-LoginFrame";
#       })
#       (makeDesktopItem {
#         name = "ib-gw-latest";
#         desktopName = "IB Gateway";
#         exec = "ib-gw-latest";
#         icon = pname;
#         categories = [
#           "Office"
#           "Finance"
#         ];
#         startupWMClass = "ibgateway-GWClient";
#       })
#     ];
#     unpackPhase = ''
#       echo "Unpacking I4J sfx sh to $PWD..."
#       INSTALL4J_TEMP="$PWD" sh "$src" __i4j_extract_and_exit
#       # JRE
#       jrePath="$out/share/${pname}/jre"
#       echo "Unpacking JRE to $jrePath..."
#       mkdir -p "$jrePath"
#       mkdir -p "$jrePath/bin"
#       tar -xf "$PWD/"*.dir/jre.tar.gz -C "$jrePath/"
#       echo "Patching JRE executables..."
#       patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
#         "$jrePath/bin/java" "$jrePath/bin/unpack200"
#       echo "Unpacking JRE pack files..."
#       for f in "$jrePath/lib/"*.jar.pack "$jrePath/lib/ext/"*.jar.pack; do
#         jar_file=`echo "$f" | awk '{ print substr($0,1,length($0)-5) }'`
#         "$jrePath/bin/unpack200" -r "$f" "$jar_file"
#         [ $? -ne 0 ] && echo "Error unpacking $f" && exit 1
#       done
#       echo "Unpacking TWS payload..."
#       INSTALL4J_JAVA_HOME_OVERRIDE="$jrePath" sh "$src" -q -dir "$PWD/"
#     '';
#     installPhase = ''
#       runHook preInstall
#       # create main startup script
#       mkdir -p "$out/bin"
#       cat<<EOF > "$out/bin/${pname}"
#       #!$SHELL
#       # get script name
#       PROG=\$(basename "\$0")
#         # Initialize our own variables
#         while getopts "h?vu:p:" opt; do
#             case "\$opt" in
#             h|\?)
#                 echo "Usage: \$0 [-v] [-u username] [-p password]"
#                 exit 0
#                 ;;
#             v)  verbose=1
#                 ;;
#             u)  username=\$OPTARG
#                 ;;
#             p)  password=\$OPTARG
#                 ;;
#             esac
#         done
#       # Load system-wide settings and per-user overrides
#       IB_CONFIG_DIR="\$HOME/.\$PROG"
#       export GDK_BACKEND=x11
#       JAVA_GC="-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70 "
#       JAVA_UI_FLAGS="-Dswing.aatext=TRUE -Dawt.useSystemAAFontSettings=on -Dsun.awt.nopixfmt=true -Dsun.java2d.noddraw=true -Dswing.boldMetal=false -Dsun.locale.formatasdefault=true"
#       JAVA_LOCALE_FLAGS="-Dsun.locale.formatasdefault=true"
#       JAVA_FLAGS="\$JAVA_GC \$JAVA_UI_FLAGS \$JAVA_LOCALE_FLAGS \$JAVA_EXTRA_FLAGS"
#       [ -f "\$HOME/.config/\$PROG.conf" ] && . "\$HOME/.config/\$PROG.conf"
#       CLASS="jclient.LoginFrame"
#       [ "\$PROG" = "ib-gw" ] && CLASS="ibgateway.GWClient"
#       cd "$out/share/${pname}/jars"
#       "$out/share/${pname}/jre/bin/java" -cp \* \$JAVA_FLAGS \$CLASS \$IB_CONFIG_DIR username="\$username" password="\$password"
#       EOF
#       chmod u+x $out/bin/${pname}
#       # create symlink for the gateway
#       ln -s "${pname}" "$out/bin/ib-gw-latest"
#       # copy files
#       mkdir -p $out/share/${pname}
#       cp -R jars $out/share/${pname}
#       install -Dm644 .install4j/tws.png $out/share/pixmaps/${pname}.png
#       runHook postInstall
#     '';
#     dontPatchELF = true;
#     dontStrip = true;
#     postFixup = ''
#       rpath+="''${rpath:+:}${lib.concatStringsSep ":" (map (a: "$jrePath/${a}") rSubPaths)}"
#       # set all the dynamic linkers
#       find $out -type f -perm -0100 \
#         -exec patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
#         --set-rpath "$rpath" {} \;
#       find $out -name "*.so" -exec patchelf --set-rpath "$rpath" {} \;
#     '';
#     rpath = lib.strings.makeLibraryPath libraries;
#     libraries = [
#       stdenv.cc
#       stdenv.cc.libc
#       glib
#       libxml2
#       ffmpeg
#       libGL
#       libXxf86vm
#       alsa-lib
#       fontconfig
#       freetype
#       pango
#       gtk3
#       cairo
#       gdk-pixbuf
#       atk
#       libX11
#       libXext
#       libXtst
#       libXi
#       libXrender
#     ];
#     # possibly missing libgdk-x11-2.0.so.0, from gtk2? never caused any trouble though
#     passthru.updateScript = ./update.sh;
#     meta = with lib; {
#       description = "Trader Work Station of Interactive Brokers";
#       homepage = "https://www.interactivebrokers.com";
#       license = licenses.mit;
#       maintainers = lib.optionals (maintainers ? k3a) [maintainers.k3a];
#       platforms = ["x86_64-linux"];
#     };
#   }

