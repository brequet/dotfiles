# OpenChamber — agentic dev environment on top of OpenCode. Upstream only
# ships an AppImage; wrapType2 extracts it so it runs without FUSE.
{
  appimageTools,
  fetchurl,
  makeDesktopItem,
}:

let
  version = "1.23.0";
  src = fetchurl {
    url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";
    hash = "sha256-FCIs3pemKIhgnt9gTWERIpqnE/tiOpq+ln/v0/iWR/w=";
  };

  # Identical derivation to the extraction wrapType2 does internally, so
  # this costs nothing extra: reuse it to grab the icon.
  extracted = appimageTools.extractType2 {
    pname = "openchamber";
    inherit version src;
  };

  desktopItem = makeDesktopItem {
    name = "openchamber";
    exec = "openchamber";
    icon = "openchamber";
    comment = "Agentic development environment";
    desktopName = "OpenChamber";
    categories = [ "Development" ];
    startupWMClass = "openchamber";
  };
in
appimageTools.wrapType2 {
  pname = "openchamber";
  inherit version src;

  # Upstream's desktop entry calls AppRun, which wrapType2 doesn't install,
  # so ship our own entry together with the icon.
  extraInstallCommands = ''
    install -Dm644 ${extracted}/openchamber.png \
      $out/share/icons/hicolor/256x256/apps/openchamber.png
    install -Dm644 ${desktopItem}/share/applications/openchamber.desktop \
      $out/share/applications/openchamber.desktop
  '';

  meta = {
    description = "Agentic development environment";
    platforms = [ "x86_64-linux" ];
  };
}
