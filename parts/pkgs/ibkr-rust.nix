{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  ...
}:
rustPlatform.buildRustPackage rec {
  pname = "ibkr-rust";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "czichy";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-e65QDbK55q1Pbv/i7bDYRY78jgEUD1q6TLdKD8Gkswk=";
  };

  nativeBuildInputs = [pkg-config];

  buildInputs = [openssl];

  # NOTE needed due to Cargo.lock containing git dependencies
  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "ibkr-rust-0.1.0" = "sha256-fCjVfmjrwMSa8MFgnC8n5jPzdaqSmNNdMRaYHNbs8Bo=";
    };
  };

  meta = with lib; {
    description = "";
    homepage = "https://github.com/czichy/ibkr-rust";
    # changelog = "https://github.com/2e3s/awatcher/releases/tag/${version}";
    license = licenses.mpl20;
    maintainers = with tensorfiles.maintainers; [czichy];
    platforms = platforms.linux;
    mainProgram = pname;
  };
}
