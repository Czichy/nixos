# https://github.com/NixOS/nixpkgs/issues/426401
# https://github.com/NixOS/nixpkgs/pull/426609
final: prev: let
  inherit
    (final)
    arrow-cpp
    fetchFromGitHub
    fetchpatch2
    runCommand
    ;

  snappy = prev.snappy.overrideAttrs (finalAttrs: {
    version = "1.2.1";

    src = fetchFromGitHub {
      owner = "google";
      repo = "snappy";
      rev = finalAttrs.version;
      hash = "sha256-IzKzrMDjh+Weor+OrKdX62cAKYTdDXgldxCgNE2/8vk=";
    };

    patches = [
      (fetchpatch2 {
        url = "https://build.opensuse.org/public/source/openSUSE:Factory/snappy/reenable-rtti.patch?rev=a759aa6fba405cd40025e3f0ab89941d";
        hash = "sha256-RMuM5yd6zP1eekN/+vfS54EyY4cFbGDVor1E1vj3134=";
      })
    ];
  });
in {
  ceph =
    (prev.ceph.override {
      inherit
        arrow-cpp
        snappy
        ;
    }).overrideAttrs
    (oldAttrs: {
      patches =
        oldAttrs.patches
        ++ [
          (fetchpatch2 {
            name = "ceph-s3select-arrow-20-compat.patch";
            url = "https://github.com/ceph/s3select/commit/58fe02f8c93cd7f4102b435ee7233aa555c7c305.patch";
            hash = "sha256-RBNBZW8esbauDXM92y/pZOjDJCcvUkAeE+G8OJj84G0=";
            stripLen = 1;
            extraPrefix = "src/s3select/";
          })
        ];
    });

  ceph-client = let
    ceph = final.ceph;
    sitePackages = ceph.python.sitePackages;
  in
    runCommand "ceph-client-${ceph.version}"
    {
      meta =
        ceph.meta
        // {
          description = "Tools needed to mount Ceph's RADOS Block Devices/Cephfs";
          outputsToInstall = ["out"];
        };
    }
    ''
      mkdir -p $out/{bin,etc,${sitePackages},share/bash-completion/completions}
      cp -r ${ceph}/bin/{ceph,.ceph-wrapped,rados,rbd,rbdmap} $out/bin
      cp -r ${ceph}/bin/ceph-{authtool,conf,dencoder,rbdnamer,syn} $out/bin
      cp -r ${ceph}/bin/rbd-replay* $out/bin
      cp -r ${ceph}/sbin/mount.ceph $out/bin
      cp -r ${ceph}/sbin/mount.fuse.ceph $out/bin
      ln -s bin $out/sbin
      cp -r ${ceph}/${sitePackages}/* $out/${sitePackages}
      cp -r ${ceph}/etc/bash_completion.d $out/share/bash-completion/completions
      # wrapPythonPrograms modifies .ceph-wrapped, so lets just update its paths
      substituteInPlace $out/bin/ceph          --replace ${ceph} $out
      substituteInPlace $out/bin/.ceph-wrapped --replace ${ceph} $out
    '';

  libceph = final.ceph.lib;
}
