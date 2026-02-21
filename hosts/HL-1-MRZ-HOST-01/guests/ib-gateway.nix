{
  inputs,
  config,
  pkgs,
  secretsPath,
  hostName,
  lib,
  ...
}: let
  # IB Gateway stable version major number (10.30 -> 1030)
  twsMajorVersion = "1019";

  ibcPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ibc;
  ibTwsPkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ib-tws-native;

  # Generate IBC config.ini from Nix
  ibcConfigFile = pkgs.writeText "ibc-config.ini" ''
    # IBC configuration - managed by NixOS
    # Credentials are passed via environment variables, not stored here
    IbLoginId=
    IbPassword=
    FIXLoginId=
    FIXPassword=
    FIX=no

    TradingMode=paper
    IbDir=

    # Accept incoming API connections automatically
    AcceptIncomingConnectionAction=accept
    ReadOnlyApi=no

    # Handle existing sessions - connect as secondary to avoid kicking out primary
    ExistingSessionDetectedAction=secondary
    ReadOnlyLogin=no

    # Accept non-brokerage (paper trading) warning
    AcceptNonBrokerageAccountWarning=yes

    # 2FA settings
    SecondFactorAuthenticationExitInterval=60
    ReloginAfterSecondFactorAuthenticationTimeout=yes

    # Auto-restart on Sundays at 02:00
    AutoRestartTime=02:00
    AutoLogoffTime=

    # Allow blind trading (no market data subscription needed)
    AllowBlindTrading=yes

    # Minimize main window
    MinimizeMainWindow=yes

    # Store settings on server for recovery
    StoreSettingsOnServer=no

    # Logging
    LogStructureScope=known
    LogStructureWhen=never
  '';

  # Script that reads secrets and launches IB Gateway via IBC
  launchScript = pkgs.writeShellScriptBin "launch-ib-gateway" ''
    set -euo pipefail

    echo "Starting IB Gateway via IBC..."

    # Read credentials from agenix secrets
    export TWSUSERID="$(cat ${config.age.secrets.ibkr-gw-user.path})"
    export TWSPASSWORD="$(cat ${config.age.secrets.ibkr-gw-password.path})"

    # IBC environment
    export TWS_MAJOR_VRSN="${twsMajorVersion}"
    export IBC_INI="/var/lib/ib-gateway/config.ini"
    export TRADING_MODE="paper"
    export TWOFA_TIMEOUT_ACTION="restart"
    export IBC_PATH="${ibcPkg}/opt/ibc"
    export TWS_PATH="/var/lib/ib-gateway/Jts"
    export TWS_SETTINGS_PATH="/var/lib/ib-gateway/Jts"
    export LOG_PATH="/var/log/ib-gateway"
    export JAVA_PATH=""
    export FIXUSERID=""
    export FIXPASSWORD=""
    export APP=GATEWAY
    export HIDE=YES
    export DISPLAY=:1

    # Ensure directories exist
    mkdir -p "$TWS_PATH" "$LOG_PATH" /var/lib/ib-gateway

    # Copy config if not present (allows persistence to override)
    if [ ! -f "$IBC_INI" ]; then
      cp ${ibcConfigFile} "$IBC_INI"
      chmod 600 "$IBC_INI"
    fi

    # Launch via IBC scripts
    exec ${ibcPkg}/opt/ibc/scripts/ibcstart.sh \
      "''${TWS_MAJOR_VRSN}" -g \
      "--tws-path=''${TWS_PATH}" \
      "--tws-settings-path=''${TWS_SETTINGS_PATH}" \
      "--ibc-path=''${IBC_PATH}" \
      "--ibc-ini=''${IBC_INI}" \
      "--user=''${TWSUSERID}" \
      "--pw=''${TWSPASSWORD}" \
      "--mode=''${TRADING_MODE}" \
      "--on2fatimeout=''${TWOFA_TIMEOUT_ACTION}"
  '';
in {
  microvm.mem = 2048;
  microvm.vcpu = 2;

  networking.hostName = hostName;

  networking.firewall = {
    allowedTCPPorts = [
      4001 # Live API
      4002 # Paper API
      5900 # VNC (optional, for debugging)
    ];
  };

  # |----------------------------------------------------------------------| #
  # Secrets
  # |----------------------------------------------------------------------| #
  age.secrets = {
    ibkr-gw-user = {
      file = secretsPath + "/ibkr/market-user.age";
      mode = "0400";
      owner = "ibgateway";
    };
    ibkr-gw-password = {
      file = secretsPath + "/ibkr/market-password.age";
      mode = "0400";
      owner = "ibgateway";
    };
  };

  # |----------------------------------------------------------------------| #
  # Users
  # |----------------------------------------------------------------------| #
  users = {
    users.ibgateway = {
      isSystemUser = true;
      group = "ibgateway";
      home = "/var/lib/ib-gateway";
      createHome = true;
    };
    groups.ibgateway = {};
  };

  # |----------------------------------------------------------------------| #
  # System packages
  # |----------------------------------------------------------------------| #
  environment.systemPackages = with pkgs; [
    ibcPkg
    ibTwsPkg
    xvfb-run
    xorg.xdpyinfo
    socat
    x11vnc
    xterm
    procps
    coreutils
    bash
    gnugrep
    gawk
    gnused
    findutils
    unzip
  ];

  # |----------------------------------------------------------------------| #
  # Systemd services
  # |----------------------------------------------------------------------| #

  # Xvfb - virtual framebuffer
  systemd.services."xvfb" = {
    description = "Xvfb virtual framebuffer";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "ibgateway";
      ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run --server-num=1 --server-args='-screen 0 1024x768x24' ${pkgs.coreutils}/bin/sleep infinity";
      # Alternative: run Xvfb directly
      # ExecStart = "${pkgs.xorg.xorgserver}/bin/Xvfb :1 -screen 0 1024x768x24";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # IB Gateway via IBC
  systemd.services."ib-gateway" = {
    description = "Interactive Brokers Gateway (via IBC)";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "xvfb.service"];
    wants = ["network-online.target" "xvfb.service"];
    requires = ["xvfb.service"];

    environment = {
      DISPLAY = ":1";
    };

    serviceConfig = {
      Type = "simple";
      User = "ibgateway";
      Group = "ibgateway";
      ExecStart = "${launchScript}/bin/launch-ib-gateway";
      Restart = "on-failure";
      RestartSec = 30;
      WorkingDirectory = "/var/lib/ib-gateway";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/var/lib/ib-gateway"
        "/var/log/ib-gateway"
      ];
    };
  };

  # socat - expose API ports to network
  # IB Gateway binds to localhost only, socat forwards to 0.0.0.0
  systemd.services."ib-gateway-socat-live" = {
    description = "socat forward for IB Gateway live API (4001)";
    wantedBy = ["multi-user.target"];
    after = ["ib-gateway.service"];
    wants = ["ib-gateway.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:4001,fork,reuseaddr TCP:127.0.0.1:4001";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.services."ib-gateway-socat-paper" = {
    description = "socat forward for IB Gateway paper API (4002)";
    wantedBy = ["multi-user.target"];
    after = ["ib-gateway.service"];
    wants = ["ib-gateway.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:4002,fork,reuseaddr TCP:127.0.0.1:4002";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # x11vnc - optional VNC server for debugging
  systemd.services."x11vnc" = {
    description = "x11vnc VNC server for IB Gateway debugging";
    wantedBy = []; # Not started by default, enable manually: systemctl start x11vnc
    after = ["xvfb.service"];
    wants = ["xvfb.service"];
    serviceConfig = {
      Type = "simple";
      User = "ibgateway";
      ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :1 -nopw -forever -shared";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # |----------------------------------------------------------------------| #
  # Persistence
  # |----------------------------------------------------------------------| #
  environment.persistence."/persist" = {
    directories = [
      {
        directory = "/var/lib/ib-gateway";
        user = "ibgateway";
        group = "ibgateway";
        mode = "0700";
      }
      {
        directory = "/var/log/ib-gateway";
        user = "ibgateway";
        group = "ibgateway";
        mode = "0700";
      }
    ];
    files = [
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
