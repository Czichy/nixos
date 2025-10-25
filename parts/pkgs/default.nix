{
  lib,
  inputs,
  projectPath,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    packages = {
      pywalfox-native = pkgs.callPackage ./pywalfox-native.nix {};
      docs = pkgs.callPackage ./docs {
        inherit
          lib
          inputs
          system
          projectPath
          ;
      };
      my_cookies = pkgs.callPackage ./my_cookies.nix {};
      ib-tws-native = pkgs.callPackage ./ibtws {};
      ib-tws-native-latest = pkgs.callPackage ./ibtws_latest {};
      affine-server = pkgs.callPackage ./affine-server.nix {};
      # ibkr-rust = pkgs.callPackage ./ibkr-rust.nix {};
      # ente-web = pkgs.callPackage ./ente-web.nix {};
      polonium-nightly = pkgs.libsForQt5.callPackage ./polonium-nightly.nix {inherit lib;};
    };
  };
}
