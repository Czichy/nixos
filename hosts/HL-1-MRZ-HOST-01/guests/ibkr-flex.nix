{
  inputs,
  config,
  pkgs,
  secretsPath,
  hostName,
  ...
}: let
  # |----------------------------------------------------------------------| #
  token = "cat ${config.age.secrets.ibkrFlexToken.path}";
  query = "639991";
  slug = "https://health.czichy.com/ping/";
  download-ibkr-flex =
    pkgs.writeShellScriptBin "ibkr-flex-download"
    ''
      #!/usr/bin/env bash
      set -euo pipefail

      echo "Downloading Flex Report"
      token="cat ${config.age.secrets.ibkrFlexToken.path}";
      /run/current-system/sw/bin/ibkr-rust-flex -q ${query} -t "echo '$token'" --dump-path /TWS_Flex_Reports

      for file in /TWS_Flex_Reports/*.xml ; do
          fileDate=$(awk -F[_.] '{print $3 }' <<<"$(basename "$file")");
          destination="$(awk -F[-] '{print $1 }' <<<"$fileDate")/$(awk -F[-] '{print $1"-"$2  }' <<<"$fileDate")/"
          echo "$destination"
          echo mv "$file" "/TWS_Flex_Reports/$destination";
      done
      pingKey="$(cat ${config.age.secrets.ibkr-flex-hc-ping.path})";
      ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused "${slug}$pingKey/ibkr-flex-download"

    '';
  # |----------------------------------------------------------------------| #
in {
  microvm.mem = 512;
  microvm.vcpu = 1;
  microvm.shares = [
    {
      # On the host
      source = "/shared/shares/users/christian/Trading/TWS_Flex_Reports";
      # In the MicroVM
      mountPoint = "/TWS_Flex_Reports";
      tag = "flex";
      proto = "virtiofs";
    }
  ];

  networking.hostName = hostName;

  # |----------------------------------------------------------------------| #
  age.secrets = {
    ibkrFlexToken = {
      symlink = true;
      file = secretsPath + "/hosts/HL-1-MRZ-HOST-01/guests/ibkr-flex/token.age";
      mode = "0600";
      owner = "root";
    };
  };
  age.secrets.ibkr-flex-hc-ping = {
    file = secretsPath + "/hosts/HL-4-PAZ-PROXY-01/healthchecks-ping.age";
    mode = "440";
  };
  # ------------------------------
  # | SYSTEM PACKAGES |
  # ------------------------------
  environment.systemPackages = with pkgs; [
    pkg-config
    openssh
    inputs.ibkr-rust.packages.${pkgs.system}.flex
  ];
  # |----------------------------------------------------------------------| #
  systemd.timers."ibkr-flex-download" = {
    wantedBy = ["timers.target"];
    timerConfig = {
      Perisistent = true;
      OnCalendar = "Mon..Fri 23:30";
      Unit = "ibkr-flex-download.service";
    };
  };

  systemd.services."ibkr-flex-download" = {
    serviceConfig = {
      Type = "simple";
      User = "root";
      ExecStart = "${download-ibkr-flex}/bin/ibkr-flex-download";
    };
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
