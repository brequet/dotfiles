# OpenChamber — agentic dev environment on top of OpenCode. Upstream only
# ships an AppImage; appimageTools.wrapType2 would run it inside a buildFHSEnv
# bubblewrap sandbox whose user namespace maps only our uid, so root-owned
# /nix/store files appear as nobody (this breaks ownership checks such as
# OpenSSH's on a store-linked ~/.ssh/config). Instead, extract the AppImage
# and let autoPatchelfHook patch its ELF files, so it runs as a plain Electron
# app in the user session.
# 2.x bundles the OpenCode 2 CLI at opt/openchamber/resources/opencode-cli,
# which autoPatchelfHook patches along with the rest of the tree, so the app
# needs no opencode on PATH. Only the app icon moved: 2.0 ships openchamber.svg
# instead of the old 256x256 openchamber.png.
# Bump with: nix run nixpkgs#nix-update -- --flake openchamber (or ./update.sh)
{
  alsa-lib,
  appimageTools,
  at-spi2-atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dbus-glib,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk2,
  gtk3,
  lib,
  libdbusmenu-gtk2,
  libdrm,
  libgbm,
  libglvnd,
  libpulseaudio,
  libsecret,
  libuuid,
  libX11,
  libxcb,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libxkbcommon,
  libXrandr,
  libXScrnSaver,
  libxshmfence,
  libXtst,
  makeDesktopItem,
  makeWrapper,
  nix-update-script,
  nspr,
  nss,
  pango,
  stdenv,
  udev,
  wrapGAppsHook3,
  xdg-utils,
  zenity,
  zlib,
}:

let
  version = "2.1.0";
  # Stays the derivation's src so `nix-update` can read the version and hash
  # straight off this fetchurl; the AppImage is extracted separately below.
  fetched = fetchurl {
    url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";
    hash = "sha256-q08g/HwXzLy+cgz8u7q9C1ksGdjn6+BmPXyz+RiggvI=";
  };

  extracted = appimageTools.extractType2 {
    pname = "openchamber";
    inherit version;
    src = fetched;
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
stdenv.mkDerivation {
  pname = "openchamber";
  inherit version;

  src = fetched;
  # stdenv cannot unpack an AppImage (an ELF with a squashfs attached), so the
  # extracted tree is copied in installPhase instead.
  dontUnpack = true;

  dontConfigure = true;
  dontBuild = true;
  # Prebuilt release binaries; keep them byte-identical apart from the
  # interpreter/RPATH rewriting autoPatchelfHook does.
  dontStrip = true;
  # Wrapped in postFixup below, once wrapGAppsHook3 has built its arguments.
  dontWrapGApps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    dbus-glib
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk2
    gtk3
    libdbusmenu-gtk2
    libdrm
    libgbm
    libglvnd
    libpulseaudio
    libsecret
    libuuid
    libX11
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libxkbcommon
    libXrandr
    libXScrnSaver
    libxshmfence
    libXtst
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/openchamber
    cp -a ${extracted}/. $out/opt/openchamber/
    chmod -R u+w $out/opt/openchamber

    install -Dm644 ${extracted}/openchamber.svg \
      $out/share/icons/hicolor/scalable/apps/openchamber.svg
    install -Dm644 ${desktopItem}/share/applications/openchamber.desktop \
      $out/share/applications/openchamber.desktop

    runHook postInstall
  '';

  postFixup = ''
    # The AppImage expects an FHS system to provide the native EGL library;
    # keep the bundled libs first (ANGLE's libEGL.so lives here) and fall
    # back to libglvnd for libEGL.so.1, or ANGLE cannot initialize and
    # Chromium silently drops to software rendering.
    makeWrapper $out/opt/openchamber/openchamber $out/bin/openchamber \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "$out/opt/openchamber:$out/opt/openchamber/usr/lib:${
        lib.makeLibraryPath [ libglvnd ]
      }" \
      --suffix XDG_DATA_DIRS : "$out/opt/openchamber/usr/share" \
      --prefix PATH : "${
        lib.makeBinPath [
          xdg-utils
          zenity
        ]
      }"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Agentic development environment";
    license = lib.licenses.mit;
    mainProgram = "openchamber";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
