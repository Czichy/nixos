#!/bin/sh
export INSTALL4J_JAVA_HOME_OVERRIDE='__JAVAHOME__'
export GDK_BACKEND=x11
# Use existing DISPLAY if set (e.g. XWayland), fall back to :0
export DISPLAY="${DISPLAY:-:0}"

# Use IBKR_CONFIG_DIR if set (from ib-start), otherwise default
CONFIG_DIR="${IBKR_CONFIG_DIR:-$HOME/.ib-tws-native}"
mkdir -p "$CONFIG_DIR"
VMOPTIONS=$CONFIG_DIR/tws.vmoptions
if [ ! -e "$VMOPTIONS" ]; then
    cp __OUT__/libexec/tws.vmoptions "$VMOPTIONS"
fi
# The vm options file should always refer to itself.
sed -i -e 's#-DvmOptionsPath=.*#-DvmOptionsPath=$VMOPTIONS#' $VMOPTIONS

# Force the correct trading mode in jts.ini before launch.
# TWS caches tradingMode from the previous session, so paper mode
# won't work if live was started before (and vice versa).
# Values: "p" = paper, "l" = live
if [ -n "$IBKR_MODE" ]; then
    JTS_INI="$CONFIG_DIR/jts.ini"
    case "$IBKR_MODE" in
        paper) MODE_FLAG="p" ;;
        live)  MODE_FLAG="l" ;;
        *)     MODE_FLAG="$IBKR_MODE" ;;
    esac

    if [ -f "$JTS_INI" ]; then
        if grep -q "^tradingMode=" "$JTS_INI"; then
            sed -i "s/^tradingMode=.*/tradingMode=$MODE_FLAG/" "$JTS_INI"
        elif grep -q '^\[Logon\]' "$JTS_INI"; then
            sed -i "/^\[Logon\]/a tradingMode=$MODE_FLAG" "$JTS_INI"
        else
            printf '[Logon]\ntradingMode=%s\n' "$MODE_FLAG" >> "$JTS_INI"
        fi
    else
        printf '[Logon]\ntradingMode=%s\n' "$MODE_FLAG" > "$JTS_INI"
    fi
fi

export LD_LIBRARY_PATH=__GTK__/lib:__CCLIBS__/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec "__OUT__/libexec/tws" -J-Dsun.java2d.uiScale=1.0 -J-DjtsConfigDir="$CONFIG_DIR" -J-Dawt.useSystemAAFontSettings=lcd -J-Dswing.aatext=true -J-Dawt.useSystemAAFontSettings=on -J-Dsun.awt.nopixfmt=true -J-Dsun.java2d.noddraw=true -J-Dswing.boldMetal=false -Dsun.locale.formatasdefault=true ${IBKR_USER:+username="$IBKR_USER"} ${IBKR_PASSWORD:+password="$IBKR_PASSWORD"} "$@"
