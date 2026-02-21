{
  stdenv,
  lib,
  fetchzip,
  makeWrapper,
  jdk17,
  xvfb-run,
}: let
  version = "3.23.0";
in
  stdenv.mkDerivation {
    pname = "ibc";
    inherit version;

    src = fetchzip {
      url = "https://github.com/IbcAlpha/IBC/releases/download/${version}/IBCLinux-${version}.zip";
      hash = "sha256-EaFEHmlqF5K8fj61F4uCXCWBfN00Aox5EhlczxB+aqo=";
      stripRoot = false;
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/ibc $out/bin

      # Install IBC files
      cp IBC.jar $out/opt/ibc/
      cp *.sh $out/opt/ibc/
      cp config.ini $out/opt/ibc/config.ini.sample
      cp -r scripts $out/opt/ibc/ 2>/dev/null || true
      chmod +x $out/opt/ibc/*.sh

      # Create gateway start wrapper
      makeWrapper ${jdk17}/bin/java $out/bin/ibc-gateway \
        --add-flags "-cp" \
        --add-flags "$out/opt/ibc/IBC.jar" \
        --add-flags "ibcalpha.ibc.IbcGateway" \
        --set IBC_PATH "$out/opt/ibc"

      # Create TWS start wrapper
      makeWrapper ${jdk17}/bin/java $out/bin/ibc-tws \
        --add-flags "-cp" \
        --add-flags "$out/opt/ibc/IBC.jar" \
        --add-flags "ibcalpha.ibc.IbcTws" \
        --set IBC_PATH "$out/opt/ibc"

      runHook postInstall
    '';

    meta = with lib; {
      description = "IB Controller - automates Interactive Brokers TWS and Gateway";
      homepage = "https://github.com/IbcAlpha/IBC";
      license = licenses.gpl3;
      platforms = platforms.linux;
    };
  }
