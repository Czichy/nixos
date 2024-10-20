# --- lib/asserts.nix
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
{ lib, ... }:
with lib;
with builtins;
{
  /*
    Asserts that the home-manager module is installed and imported.

    *Type*: `assertHomeManagerLoaded :: AttrSet a -> (AttrSet a | Error)`

    Example:
    ```nix title="Example" linenums="1"
    config = mkIf cfg.enable (mkMerge [
      ({
        assertions = with tensorfiles.asserts;
          [ (mkIf cfg.home.enable (assertHomeManagerLoaded config)) ];
      })
     ]);
    ```
  */
  assertHomeManagerLoaded =
    # (AttrSet) An AttrSet with the already parsed NixOS config
    cfg: {
      assertion = hasAttr "home-manager" cfg;
      message = ''
        Home configuration is enabled, however, the required home-manager module is
        missing. Please, install and import home-manager for the module to work
        properly.
      '';
    };
}
