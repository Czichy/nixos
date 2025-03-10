{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  glib,
  # stdenv,
  # mandown,
  # installShellFiles,
  # curl,
  # versionCheckHook,
  # nix-update-script,
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

  env.OPENSSL_NO_VENDOR = 1;

  nativeBuildInputs = [
    openssl
    pkg-config
  ];

  buildInputs = [
    openssl
    glib
    openssl.dev
    pkg-config
  ];

  cargoHash = "sha256-38hTOsa1a5vpR1i8GK1aq1b8qaJoCE74ewbUOnun+Qs=";

  # NOTE needed due to Cargo.lock containing git dependencies
  # cargoLock = {
  #   lockFile = ./Cargo.lock;
  #   outputHashes = {
  #     "ibkr-rust-0.1.0" = "sha256-fCjVfmjrwMSa8MFgnC8n5jPzdaqSmNNdMRaYHNbs8Bo=";
  #   };
  # };

  # preCheck = ''
  #   HOME=$(mktemp -d)
  # '';

  # nativeInstallCheckInputs = [
  #   versionCheckHook
  # ];
  # versionCheckProgramArg = [ "--version" ];
  # doInstallCheck = true;

  # # Ensure that we don't vendor curl, but instead link against the libcurl from nixpkgs
  # installCheckPhase = lib.optionalString (stdenv.hostPlatform.libc == "glibc") ''
  #   runHook preInstallCheck

  #   ldd "$out/bin/zellij" | grep libcurl.so

  #   runHook postInstallCheck
  # '';

  # postInstall =
  #   ''
  #     mandown docs/MANPAGE.md > zellij.1
  #     installManPage zellij.1
  #   ''
  #   + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
  #     installShellCompletion --cmd $pname \
  #       --bash <($out/bin/zellij setup --generate-completion bash) \
  #       --fish <($out/bin/zellij setup --generate-completion fish) \
  #       --zsh <($out/bin/zellij setup --generate-completion zsh)
  #   '';

  # passthru.updateScript = nix-update-script { };

  # meta = {
  #   description = "Terminal workspace with batteries included";
  #   homepage = "https://zellij.dev/";
  #   changelog = "https://github.com/zellij-org/zellij/blob/v${version}/CHANGELOG.md";
  #   license = with lib.licenses; [ mit ];
  #   maintainers = with lib.maintainers; [
  #     therealansh
  #     _0x4A6F
  #     abbe
  #     pyrox0
  #   ];
  #   mainProgram = "zellij";
  # };

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
