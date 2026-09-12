{ config, pkgs, zen-browser, nixpkgs-unstable, ... }:

let
  unstable = nixpkgs-unstable.legacyPackages.${pkgs.system};

  # OpenChamber — agentic dev environment on top of OpenCode. Only shipped
  # as an AppImage; wrapType2 extracts it so it runs without FUSE, then add
  # the desktop entry (the upstream one calls AppRun, which we don't ship)
  # and icon so it shows up in GNOME.
  openchamber = let
    version = "1.23.0";
    src = pkgs.fetchurl {
      url = "https://github.com/openchamber/openchamber/releases/download/v${version}/OpenChamber-${version}-linux-x86_64.AppImage";
      sha256 = "1z27jvwd7vvzjsz9lfk2zc9sg6i225hlsq6zkrh8ha56jzg2q8hl";
    };
  in
  pkgs.symlinkJoin {
    name = "openchamber-${version}";
    paths = [
      (pkgs.appimageTools.wrapType2 { pname = "openchamber"; inherit version src; })
      (pkgs.makeDesktopItem {
        name = "openchamber";
        exec = "openchamber";
        icon = "openchamber";
        comment = "Agentic development environment";
        desktopName = "OpenChamber";
        categories = [ "Development" ];
        startupWMClass = "openchamber";
      })
    ];
    postBuild = ''
      install -Dm644 ${pkgs.appimageTools.extractType2 { pname = "openchamber"; inherit version src; }}/openchamber.png \
        $out/share/icons/hicolor/256x256/apps/openchamber.png
    '';
  };
in

{
  home.stateVersion = "26.05";

  # Symlinked out of the store so Zed's settings editor writes through to the
  # repo working copy; only Nix changes need a rebuild.
  xdg.configFile = {
    "zed/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/zed/settings.json";
    "zed/keymap.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/zed/keymap.json";
  };

  home.packages = with pkgs; [
    zen-browser.packages."${pkgs.system}".default
    chromium
    obsidian
    helix
    eza
    bat
    ripgrep
    yazi
    btop
    unstable.opencode
    openchamber
    package-version-server
  ];
}
