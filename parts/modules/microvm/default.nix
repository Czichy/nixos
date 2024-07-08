# --- parts/modules/nixos/default.nix
#
# Author:  czichy <christian@czichy.com>
# URL:     https://github.com/czichy/tensorfiles
# License: MIT
#
# 888                                                .d888 d8b 888
# 888                                               d88P"  Y8P 888
# 888                                               888        888
# 888888 .d88b.  88888b.  .d8888b   .d88b.  888d888 888888 888 888  .d88b.  .d8888b
# 888   d8P  Y8b 888 "88b 88K      d88""88b 888P"   888    888 888 d8P  Y8b 88K
# 888   88888888 888  888 "Y8888b. 888  888 888     888    888 888 88888888 "Y8888b.
# Y88b. Y8b.     888  888      X88 Y88..88P 888     888    888 888 Y8b.          X88
#  "Y888 "Y8888  888  888  88888P'  "Y88P"  888     888    888 888  "Y8888   88888P'
{
  config,
  inputs,
  self,
  ...
}: let
  inherit (inputs.flake-parts.lib) importApply;
  localFlake = self;
in {
  flake.nixosModules = {
    # -- micro vm --
    services_microvm = importApply ./services/virtualisation/microvm.nix {inherit localFlake;};

    services_microvm_test = importApply ./services/virtualisation/microvm/test.nix {
      inherit localFlake;
      inherit (config.secrets) secretsPath pubkeys;
    };

    # services_microvm_influxdb = importApply ./services/virtualisation/microvm/influxdb.nix {
    #   inherit localFlake;
    #   inherit (config.secrets) secretsPath pubkeys;
    # };
  };
}
