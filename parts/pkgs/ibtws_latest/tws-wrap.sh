#!/bin/sh
export INSTALL4J_JAVA_HOME_OVERRIDE='__JAVAHOME__'
export GDK_BACKEND=x11

# JAVA_GC="-Xmx4G -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:InitiatingHeapOccupancyPercent=70 "
JAVA_UI_FLAGS="-J-Dsun.java2d.uiScale=1.0 -J-Dswing.aatext=TRUE -J-Dawt.useSystemAAFontSettings=on -J-Dsun.awt.nopixfmt=true -J-Dsun.java2d.noddraw=true -J-Dswing.boldMetal=false -J-Dsun.locale.formatasdefault=true"
JAVA_LOCALE_FLAGS="-J-Dsun.locale.formatasdefault=true -J-DjtsConfigDir=$HOME/.tws-latest"
JAVA_FLAGS="\$JAVA_UI_FLAGS \$JAVA_LOCALE_FLAGS \$JAVA_EXTRA_FLAGS"
# JAVA_FLAGS="\$JAVA_GC \$JAVA_UI_FLAGS \$JAVA_LOCALE_FLAGS \$JAVA_EXTRA_FLAGS"


mkdir -p $HOME/.tws-latest
VMOPTIONS=$HOME/.tws-latest/tws.vmoptions
if [ ! -e tws.vmoptions ]; then
    cp __OUT__/libexec/tws.vmoptions $HOME/.tws-latest
fi
# The vm options file should always refer to itself.
sed -i -e 's#-DvmOptionsPath=.*#-DvmOptionsPath=$VMOPTIONS#' $VMOPTIONS
export LD_LIBRARY_PATH=__GTK__/lib:__CCLIBS__/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec "__OUT__/libexec/tws" -J-Dsun.java2d.uiScale=1.0 -J-DjtsConfigDir=$HOME/.tws-latest --J-Dawt.useSystemAAFontSettings=lcd -J-Dswing.aatext=true -J-Dawt.useSystemAAFontSettings=on -J-Dsun.awt.nopixfmt=true -J-Dsun.java2d.noddraw=true -J-Dswing.boldMetal=false -Dsun.locale.formatasdefault=true username=czich-paper "$@"

# cd "$out/share/${pname}/jars"
# "$out/share/${pname}/jre/bin/java" -cp \* \$JAVA_FLAGS \$CLASS \$IB_CONFIG_DIR username="\$username" password="\$password"
