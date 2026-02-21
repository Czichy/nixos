{
  localFlake,
  inputs,
  secretsPath,
}: {
  config,
  lib,
  system,
  hostName,
  pkgs,
  ...
}:
with builtins;
with lib; let
  inherit
    (localFlake.lib)
    isModuleLoadedAndEnabled
    mkImpermanenceEnableOption
    mkAgenixEnableOption
    mkOverrideAtHmModuleLevel
    ;

  cfg = config.tensorfiles.hm.programs.ib-tws;
  _ = mkOverrideAtHmModuleLevel;

  impermanenceCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.system.impermanence") && cfg.impermanence.enable;
  impermanence =
    if impermanenceCheck
    then config.tensorfiles.hm.system.impermanence
    else {};

  agenixCheck =
    (isModuleLoadedAndEnabled config "tensorfiles.hm.security.agenix") && cfg.agenix.enable;

  # Wrapper script that reads credentials from agenix and starts the right TWS/Gateway variant
  ib-start = pkgs.writeShellScriptBin "ib-start" ''
    set -euo pipefail

    # Defaults
    APP="tws"
    MODE="paper"
    CHANNEL="stable"

    usage() {
      echo "Usage: ib-start [--app tws|gateway] [--mode live|paper] [--channel stable|latest]"
      echo ""
      echo "Starts IB TWS or Gateway with credentials from agenix secrets."
      echo ""
      echo "Options:"
      echo "  --app       tws or gateway (default: tws)"
      echo "  --mode      live or paper (default: paper)"
      echo "  --channel   stable or latest (default: stable)"
      echo "  --help      Show this help"
      exit 0
    }

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --app) APP="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --channel) CHANNEL="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done

    # Read credentials from agenix secrets (defined in credentials.nix)
    AGENIX_DIR="''${XDG_RUNTIME_DIR}/agenix.d/1"
    if [[ "$MODE" == "paper" ]]; then
      USER_SECRET="$AGENIX_DIR/ibkr_paper_user"
      PASS_SECRET="$AGENIX_DIR/ibkr_paper_password"
    else
      USER_SECRET="$AGENIX_DIR/ibkr_user"
      PASS_SECRET="$AGENIX_DIR/ibkr_password"
    fi

    if [[ -f "$USER_SECRET" && -f "$PASS_SECRET" ]]; then
      export IBKR_USER="$(cat "$USER_SECRET")"
      export IBKR_PASSWORD="$(cat "$PASS_SECRET")"
    else
      echo "Warning: Credentials not found, starting without auto-login."
      echo "  Expected: $USER_SECRET and $PASS_SECRET"
    fi

    # Set per-constellation config directory to keep settings separate
    export IBKR_CONFIG_DIR="$HOME/.ib-''${APP}-''${MODE}-''${CHANNEL}"
    mkdir -p "$IBKR_CONFIG_DIR"

    # Select the right binary
    if [[ "$CHANNEL" == "latest" ]]; then
      if [[ "$APP" == "gateway" ]]; then
        echo "Error: Gateway is not available in the latest channel. Use --channel stable instead."
        exit 1
      fi
      BIN="ib-tws-latest"
    else
      if [[ "$APP" == "gateway" ]]; then
        BIN="ib-gw"
      else
        BIN="ib-tws-native"
      fi
    fi

    echo "Starting IB $APP ($CHANNEL) in $MODE mode..."
    echo "Config dir: $IBKR_CONFIG_DIR"
    exec "$BIN" "$@"
  '';

  # Desktop entries for walker integration
  mkDesktopEntry = name: app: mode: channel: icon:
    pkgs.makeDesktopItem {
      inherit name;
      desktopName = "IB ${
        if app == "tws"
        then "TWS"
        else "Gateway"
      } ${
        if channel == "stable"
        then "Stable"
        else "Latest"
      } ${
        if mode == "live"
        then "Live"
        else "Paper"
      }";
      exec = "${ib-start}/bin/ib-start --app ${app} --mode ${mode} --channel ${channel}";
      icon = icon;
      categories = ["Office" "Finance"];
      comment = "Interactive Brokers ${
        if app == "tws"
        then "Trader Workstation"
        else "Gateway"
      } (${channel}, ${mode})";
    };
in {
  options.tensorfiles.hm.programs.ib-tws = with types; {
    enable = mkEnableOption ''
      Interactive Brokers TWS and Gateway with auto-login via agenix secrets.
    '';
    impermanence = {
      enable = mkImpermanenceEnableOption;
    };
    agenix = {
      enable = mkAgenixEnableOption;
    };
    # Credentials are managed centrally in credentials.nix (ibkr_user, ibkr_password, ibkr_paper_user, ibkr_paper_password)
  };

  config = mkIf cfg.enable (mkMerge [
    # |----------------------------------------------------------------------| #
    {
      home.packages = [
        inputs.self.packages.${system}.ib-tws-native
        inputs.self.packages.${system}.ib-tws-native-latest
        ib-start
        # Desktop entries for walker
        (mkDesktopEntry "ib-tws-stable-paper" "tws" "paper" "stable" "ib-tws-native")
        (mkDesktopEntry "ib-tws-stable-live" "tws" "live" "stable" "ib-tws-native")
        (mkDesktopEntry "ib-tws-latest-paper" "tws" "paper" "latest" "ib-tws-native")
        (mkDesktopEntry "ib-tws-latest-live" "tws" "live" "latest" "ib-tws-native")
        (mkDesktopEntry "ib-gw-stable-paper" "gateway" "paper" "stable" "ib-tws-native")
        (mkDesktopEntry "ib-gw-stable-live" "gateway" "live" "stable" "ib-tws-native")
      ];
    }
    # |----------------------------------------------------------------------| #
    # Credentials are defined in credentials.nix, no duplicate secrets needed here
    # |----------------------------------------------------------------------| #
    (mkIf impermanenceCheck {
      home.persistence."${impermanence.persistentRoot}" = {
        directories = [
          # Legacy config dirs (direct invocation without ib-start)
          ".ib-tws-native"
          ".tws-latest"
          ".ib-gw"
          # Per-constellation config dirs (via ib-start)
          ".ib-tws-paper-stable"
          ".ib-tws-live-stable"
          ".ib-tws-paper-latest"
          ".ib-tws-live-latest"
          ".ib-gateway-paper-stable"
          ".ib-gateway-live-stable"
        ];
      };
    })
    # |----------------------------------------------------------------------| #
  ]);

  meta.maintainers = with localFlake.lib.maintainers; [czichy];
}
