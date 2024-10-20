# --- parts/pkgs/default.nix
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
  lib,
  inputs,
  projectPath,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = {
        pywalfox-native = pkgs.callPackage ./pywalfox-native.nix { };
        docs = pkgs.callPackage ./docs {
          inherit
            lib
            inputs
            system
            projectPath
            ;
        };
        my_cookies = pkgs.callPackage ./my_cookies.nix { };
        ib-tws-native = pkgs.callPackage ./ibtws { };
        ib-tws-native-latest = pkgs.callPackage ./ibtws_latest { };
        polonium-nightly = pkgs.libsForQt5.callPackage ./polonium-nightly.nix { inherit lib; };
      };
    };
}
