{
  pkgs,
  secretsPath,
  hostName,
  ...
}:
# let
# |----------------------------------------------------------------------| #
# |----------------------------------------------------------------------| #
# in
{
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
    # inputs.self.packages.${system}.ibkr-rust
    (
      let
        token = "$(cat ${config.age.secrets.ibkrFlexToken.path})";
        query = "639991";

        pingKey = "$(cat ${config.age.secrets.ibkr-flex-hc-ping.path})";
        slug = "https://health.czichy.com/ping/${pingKey}";
      in
        writeShellScriptBin "ibkr-flex-download"
        ''
          #!/usr/bin/env bash
          set -euo pipefail

          echo "Downloading Flex Report"
          nix run github:czichy/ibkr-rust/flex -q ${query} -t "echo '${token}'" --dump-path /TWS_Flex_Reports  \
          --extra-experimental-features "nix-command flakes"

          for file in /TWS_Flex_Reports/*.xml ; do
              fileDate=$(awk -F[_.] '{print $3 }' <<<"$(basename "$file")");
              destination="$(awk -F[-] '{print $1 }' <<<"$fileDate")/$(awk -F[-] '{print $1"-"$2  }' <<<"$fileDate")/"
              echo "$destination"
              echo mv "$file" "/TWS_Flex_Reports/$destination";
          done
          ${pkgs.curl}/bin/curl -m 10 --retry 5 --retry-connrefused ${slug}/ibkr-flex-download

        ''
    )
    # inputs.ibkr-rust.packages.${pkgs.system}.flex
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
    script = ''
      set -eu
      ${pkgs.ibkr.flex-download}
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # |----------------------------------------------------------------------| #
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
  # fileSystems = lib.mkMerge [
  #   {
  #     "/shared".neededForBoot = true;
  #   }
  # ];
  # |----------------------------------------------------------------------| #
  systemd.network.enable = true;
  system.stateVersion = "24.05";
}
