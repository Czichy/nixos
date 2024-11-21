{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  plasma-framework,
}:
# how to update:
# 1. check out the tag for the version in question
# 2. run `prefetch-npm-deps package-lock.json`
# 3. update npmDepsHash with the output of the previous step
buildNpmPackage {
  pname = "polonium";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "zeroxoneafour";
    repo = "polonium";
    rev = "515f6990c848d935c56de5e12cec74ca4aab1baf";
    hash = "sha256-ZaeyMbYWrfUNR9nx7y3SRNSHq3EPLkLXQ1AZJ9dzoGU=";
  };

  npmDepsHash = "sha256-kaT3Uyq+/JkmebakG9xQuR4Kjo7vk6BzI1/LffOj/eo=";

  dontConfigure = true;

  # the installer does a bunch of stuff that fails in our sandbox, so just build here and then we
  # manually do the install
  buildFlags = [
    "res"
    "src"
  ];

  nativeBuildInputs = [plasma-framework];

  dontNpmBuild = true;

  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    plasmapkg2 --install pkg --packageroot $out/share/kwin/scripts

    runHook postInstall
  '';

  meta = with lib; {
    description = "Auto-tiler that uses KWin 5.27+ tiling functionality";
    license = licenses.mit;
    maintainers = with maintainers; [peterhoeg];
    inherit (plasma-framework.meta) platforms;
  };
}
