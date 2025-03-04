#!/bin/sh
export INSTALL4J_JAVA_HOME_OVERRIDE='__JAVAHOME__'
export GDK_BACKEND=x11

export _JAVA_AWT_WM_NONREPARENTING=1
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export GDK_BACKEND=wayland
export GDK_SCALE=2
export QT_SCALE_FACTOR=2
export XCURSOR_SIZE=32


JAVA_GC="-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70 "
JAVA_UI_FLAGS="-Dswing.aatext=TRUE -Dawt.useSystemAAFontSettings=on -Dsun.awt.nopixfmt=true -Dsun.java2d.noddraw=true -Dswing.boldMetal=false -Dsun.locale.formatasdefault=true"
JAVA_LOCALE_FLAGS="-Dsun.locale.formatasdefault=true -DjtsConfigDir=$HOME/.tws-latest"
JAVA_FLAGS="\$JAVA_GC \$JAVA_UI_FLAGS \$JAVA_LOCALE_FLAGS \$JAVA_EXTRA_FLAGS"


mkdir -p $HOME/.tws-latest
VMOPTIONS=$HOME/.tws-latest/tws.vmoptions
if [ ! -e tws.vmoptions ]; then
    cp __OUT__/libexec/tws.vmoptions $HOME/.tws-latest
fi
# The vm options file should always refer to itself.
sed -i -e 's#-DvmOptionsPath=.*#-DvmOptionsPath=$VMOPTIONS#' $VMOPTIONS
export LD_LIBRARY_PATH=__GTK__/lib:__CCLIBS__/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec "__OUT__/libexec/tws" -J-Dsun.java2d.uiScale=1.0 -J-DjtsConfigDir=$HOME/.tws-latest --J-Dawt.useSystemAAFontSettings=lcd -J-Dswing.aatext=true "$@"
# exec "__OUT__/libexec/tws"  --J-Dawt.useSystemAAFontSettings=lcd -J-Dswing.aatext=true "$@"

# cd "$out/share/${pname}/jars"
# "$out/share/${pname}/jre/bin/java" -cp \* \$JAVA_FLAGS \$CLASS \$IB_CONFIG_DIR username="\$username" password="\$password"
