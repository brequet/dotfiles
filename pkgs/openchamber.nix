# OpenChamber — agentic dev environment on top of OpenCode. Upstream only
# ships an AppImage; appimageTools.wrapType2 would run it inside a buildFHSEnv
# bubblewrap sandbox whose user namespace maps only our uid, so root-owned
# /nix/store files appear as nobody (this breaks ownership checks such as
# OpenSSH's on a store-linked ~/.ssh/config). Instead, extract the AppImage
# and let autoPatchelfHook patch its ELF files, so it runs as a plain Electron
# app in the user session.
# Bump with: nix run nixpkgs#nix-update -- --flake openchamber
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
  version = "1.23.0";
  src = fetchurl {
    url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";
    hash = "sha256-FCIs3pemKIhgnt9gTWERIpqnE/tiOpq+ln/v0/iWR/w=";
  };

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
stdenv.mkDerivation {
  pname = "openchamber";
  inherit version;

  src = extracted;

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
    cp -a . $out/opt/openchamber/
    chmod -R u+w $out/opt/openchamber

    install -Dm644 ${extracted}/openchamber.png \
      $out/share/icons/hicolor/256x256/apps/openchamber.png
    install -Dm644 ${desktopItem}/share/applications/openchamber.desktop \
      $out/share/applications/openchamber.desktop

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/opt/openchamber/openchamber $out/bin/openchamber \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "$out/opt/openchamber:$out/opt/openchamber/usr/lib" \
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
  };
}
