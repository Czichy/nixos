{lib, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    overlays = {
      ceph-client = pkgs.callPackage ./ceph-client.nix {inherit lib;};
    };
  };
}
# _: {
#   perSystem = _: {
#     #
#   };
# }

