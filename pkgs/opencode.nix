# OpenCode 2 — the AI coding agent, successor to the 1.x line nixpkgs still
# ships (it builds 1.x from source with bun, which needs a node_modules fixed
# output per version). Upstream publishes v2 as prebuilt binaries on npm:
# @opencode/cli is a thin installer and @opencode/cli-linux-x64 is the
# Bun-compiled binary itself, so repack that tarball like openchamber.
# Use the -baseline package instead on CPUs without AVX2.
# Bump with: nix run nixpkgs#nix-update -- --flake opencode (or ./update.sh)
{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  ripgrep,
  stdenv,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "2.0.16";

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${finalAttrs.version}.tgz";
    hash = "sha256-CCIetqeBNU6b47ORirW32Rr/LyBznn4uCvgbzcCCLIo=";
  };

  sourceRoot = "package";

  strictDeps = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  # Bun links against glibc only today; keep libgcc around in case the
  # prebuilt binary grows C++ dependencies.
  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;
  # Bun-compiled binaries don't survive stripping.
  dontStrip = true;

  # --version must not reach out to models.dev; install checks run offline.
  env.OPENCODE_DISABLE_MODELS_FETCH = 1;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode $out/bin/opencode
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set OPENCODE_DISABLE_AUTOUPDATE true

    runHook postInstall
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
