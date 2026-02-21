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
  twsJdk = pkgs.jdk17;
  ibDerivation = stdenv.mkDerivation rec {
    version = "10.44";
    pname = "ib-tws-stable";

    src = fetchurl {
      url = "https://download2.interactivebrokers.com/installers/tws/stable-standalone/tws-stable-standalone-linux-x64.sh";
      hash = "sha256-sewvJJKyfvSI0tFYKPQGtmSFHGxqETRxcuaZ0DWa+J4=";
      executable = true;
    };

    preferLocalBuild = true;

    phases = ["installPhase"];

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      # Use an FHS environment because the installer unpacks and immediately
      # calls a binary. Patching ld-linux in between is not feasible.
      ${buildFHSEnvChroot {
        name = "fhs";
        targetPkgs = pkgs1: [
          libz
        ];
      }}/bin/fhs ${src} -q -dir $out/libexec

      # Disable the JRE compatibility check so we can use our own JDK
      sed -i 's#test_jvm "$INSTALL4J_JAVA_HOME_OVERRIDE"#app_java_home="$INSTALL4J_JAVA_HOME_OVERRIDE"#' $out/libexec/tws

      # Make the tws launcher script read $HOME/.tws/tws.vmoptions
      sed -i -e 's#read_vmoptions "$prg_dir/$progname.vmoptions"#read_vmoptions "$HOME/.tws/$progname.vmoptions"#' $out/libexec/tws

      mkdir $out/bin
      sed -e s#__OUT__#$out# -e s#__JAVAHOME__#${twsJdk.home}# -e s#__GTK__#${pkgs.gtk3}# -e s#__CCLIBS__#${pkgs.stdenv.cc.cc.lib}# ${./tws-wrap.sh} > $out/bin/ib-tws-native

      chmod a+rx $out/bin/ib-tws-native

      # Gateway symlink
      ln -s ib-tws-native $out/bin/ib-gw
    '';

    meta = with lib; {
      description = "Trader Work Station of Interactive Brokers (Stable)";
      homepage = "https://www.interactivebrokers.com";
      license = licenses.unfree;
      maintainers = [maintainers.clefru];
      platforms = platforms.linux;
    };
  };
in
  buildFHSEnv {
    name = "ib-tws-native";
    targetPkgs = pkgs1: [
      ibDerivation

      # Chromium / JxBrowser dependencies
      libxfixes
      alsa-lib
      libxcomposite
      cairo
      libxcb
      pango
      glib
      atk
      at-spi2-core
      at-spi2-atk
      libxext
      libdrm
      nspr
      nss
      cups
      mesa
      expat
      dbus
      libxdamage
      libxrandr
      libx11
      libxshmfence
      libxkbcommon
      systemd
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
    runScript = "env GDK_BACKEND=x11 /usr/bin/ib-tws-native";
  }
