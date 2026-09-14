# Host "ideapad" — Lenovo IdeaPad Pro 5 14AHP9, NixOS + Windows dual boot.
# Rebuild:   sudo nixos-rebuild switch --flake ~/dotfiles#ideapad
# Rollback:  sudo nixos-rebuild switch --rollback
{
  config, inputs, lib, pkgs, zen-browser, nixpkgs-unstable, ...
}:

let
  # libinput-config — LD_PRELOAD shim that scales scroll speed, since
  # neither libinput nor GNOME exposes a scroll-speed setting. Upstream is
  # archived (superseded by libinput's Lua plugins), but it still works.
  libinput-config = pkgs.stdenv.mkDerivation {
    pname = "libinput-config";
    version = "2025-11-25";
    src = pkgs.fetchFromGitLab {
      owner = "warningnonpotablewater";
      repo = "libinput-config";
      rev = "6f359b8b3910a0658960c81004eb7779fbde4568";
      sha256 = "sha256-flIjDFikwYMshCWEqXVaxSncSXCebCG3T4K0REIo2mY=";
    };
    nativeBuildInputs = [ pkgs.meson pkgs.ninja pkgs.pkg-config ];
    buildInputs = [ pkgs.libinput pkgs.udev ];
    # non_glibc: preload via LD_PRELOAD env var instead of /etc/ld.so.preload
    # (which we don't want to touch on NixOS). Redirect the hardcoded /etc
    # install paths and the missing /bin/true into the store.
    mesonFlags = [ "-Dnon_glibc=true" ];
    postPatch = ''
      substituteInPlace meson.build \
        --replace-fail "install_dir: '/etc/profile.d'" "install_dir: get_option('prefix') / 'etc/profile.d'" \
        --replace-fail "install_dir: '/etc/fish/conf.d'" "install_dir: get_option('prefix') / 'etc/fish/conf.d'" \
        --replace-fail "'/bin/true'" "'true'"
    '';
  };

  # 26.05 ships dms-shell 1.4.6; unstable has 1.5.3. The service below is
  # hand-wired to niri.service instead of programs.dms-shell, whose default
  # target would also start it inside the GNOME session.
  unstable = nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Noctalia shell from upstream's flake; it builds against Noctalia's own
  # pinned nixpkgs-unstable, independent of our inputs.
  noctalia-pkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in

{
  imports = [ ./hardware-configuration.nix ];

  # GRUB on our own 1G ESP (/boot); os-prober finds the Windows Boot Manager
  # on the 100M Windows ESP and adds it to the menu. NixOS is the default entry.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 10;
  };

  # Catppuccin Mocha. autoEnable is off here so only the system-level ports
  # below apply; application theming is pulled in by home-manager.
  catppuccin = {
    enable = true;
    flavor = "mocha";
    accent = "mauve";
    autoEnable = false;
    cache.enable = true;
    grub.enable = true;
    cursors.enable = true;
  };

  fonts.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  fonts.fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];

  boot.supportedFilesystems = [ "ntfs3" ];

  fileSystems."/mnt/shared" = {
    device = "/dev/disk/by-uuid/45AF523D081CD914";
    fsType = "ntfs3";
    options = [
      "uid=1000"
      "gid=100"
      "umask=0027"
      "windows_names"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
    ];
  };

  systemd.tmpfiles.rules = [ "d /mnt/shared 0755 root root -" ];

  # Windows keeps the RTC on local time; without this the clock jumps per OS switch.
  time.hardwareClockInLocalTime = true;

  # fish as the interactive shell
  programs.fish.enable = true;
  users.users.brequet.shell = pkgs.fish;

  programs.direnv.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # The nix store grows fast across rebuilds; trim old generations weekly.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # Make Ghostty the system-wide default terminal (xdg-terminal-exec spec)
  xdg.terminal-exec = {
    enable = true;
    settings = {
      default = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  # Retire GNOME Console - Ghostty replaces it everywhere
  environment.gnome.excludePackages = [ pkgs.gnome-console ];

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            accent-color = "purple";
          };
          "org/gnome/shell" = {
            favorite-apps = [
              "zen.desktop"
              "org.gnome.Nautilus.desktop"
              "com.mitchellh.ghostty.desktop"
              "dev.zed.Zed.desktop"
              "openchamber.desktop"
            ];
          };
        };
      }
    ];
  };

  xdg.mime.defaultApplications = {
    "text/html" = "zen.desktop";
    "x-scheme-handler/http" = "zen.desktop";
    "x-scheme-handler/https" = "zen.desktop";
    "x-scheme-handler/about" = "zen.desktop";
    "x-scheme-handler/unknown" = "zen.desktop";
  };

  # efibootmgr: manage UEFI boot order (dual boot). GRUB's installer pulls in
  # os-prober by itself when useOSProber is enabled, so we don't list it here.
  environment.systemPackages = with pkgs; [ git efibootmgr zed-editor ghostty gnomeExtensions.caffeine ]
    # dms-shell/quickshell/matugen only remain for the dms-greeter login
    # screen; the niri session shell itself is Noctalia now
    # (systemd.user.services.noctalia below).
    ++ (with unstable; [ dms-shell quickshell matugen ]);

  networking.hostName = "ideapad";
  networking.networkmanager.enable = true;
  # Realtek 8852CE is unstable with Wi-Fi powersave enabled.
  networking.networkmanager.wifi.powersave = false;

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Login screen: DankMaterialShell's greeter on greetd, replacing GDM/GNOME.
  # It runs its own niri instance as user "dms-greeter" and reuses brequet's
  # DMS theme/wallpaper/colors via configHome.
  services.displayManager.dms-greeter = {
    enable = true;
    package = unstable.dms-shell;
    quickshell.package = unstable.quickshell;
    # Kept as a real file so it can be validated on every build (system.checks
    # below); it replaces DMS's built-in greeter config, hence the defaults.
    compositor = {
      name = "niri";
      customConfig = builtins.readFile ./dms-greeter-niri.kdl;
    };
    configHome = "/home/brequet";
  };

  # Parse the hand-written and greeter niri configs while the system is being
  # built, so a syntax error fails `nixos-rebuild` instead of the login screen
  # (learned the hard way: `xkb { layout "fr" }` on one line is not valid KDL).
  # system.checks are build dependencies only and stay out of the closure.
  system.checks = [
    (pkgs.runCommand "niri-config-check" { nativeBuildInputs = [ config.programs.niri.package ]; } ''
      niri validate -c ${./dms-greeter-niri.kdl}
      niri validate -c ${../../home/niri/config.kdl}
      touch $out
    '')
  ];

  # GNOME stays installed as a fallback session in the greeter, but skip the
  # background daemons its module enables system-wide (file indexers, DLNA,
  # mDNS, color management). Re-enable services.avahi if CUPS stops finding
  # network printers.
  services.gnome.localsearch.enable = false;
  services.gnome.tinysparql.enable = false;
  services.gnome.rygel.enable = false;
  services.dleyna.enable = false;
  services.avahi.enable = false;
  services.colord.enable = false;

  services.desktopManager.gnome.enable = true;

  # Extra Wayland session to test-drive alongside GNOME. Keybinds/config live
  # in ~/dotfiles/home/niri (symlinked by home-manager); pick niri or GNOME
  # from the session list on the greetd login screen.
  programs.niri.enable = true;

  # Noctalia trial: a native C++/OpenGL ES shell for niri (bar, launcher,
  # control center, notifications, lock screen). Same wiring as the DMS unit
  # it replaces: a user service bound to niri.service so it never starts in
  # the GNOME session. Settings live in programs.noctalia (home-manager).
  systemd.user.services.noctalia = {
    description = "Noctalia shell";
    wantedBy = [ "niri.service" ];
    partOf = [ "niri.service" ];
    after = [ "niri.service" ];
    requisite = [ "niri.service" ];
    restartIfChanged = true;
    # NixOS injects a minimal PATH into units; clear it so noctalia inherits
    # the session's, where apps launched from its launcher live.
    path = lib.mkForce [ ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${noctalia-pkg}/bin/noctalia";
      Restart = "on-failure";
      LimitNOFILE = 16384;
      TimeoutStopSec = 10;
    };
  };

  # Power profiles: feed Noctalia's control center and bar power widget.
  services.power-profiles-daemon.enable = true;

  services.xserver.xkb = {
    layout = "fr";
    variant = "";
  };
  console.keyMap = "fr";

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth for the Realtek 8852CE combo.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Firmware updates; TRIM for the SSD.
  services.fwupd.enable = true;
  services.fstrim.enable = true;

  # Compressed in-RAM swap.
  zramSwap.enable = true;

  users.users.brequet = {
    isNormalUser = true;
    description = "brequet";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Move pre-existing files to <file>.bak on first activation instead of
    # failing with a collision error.
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs zen-browser nixpkgs-unstable; };
    sharedModules = [ inputs.catppuccin.homeModules.catppuccin ];
    users.brequet = import ../../home/brequet.nix;
  };

  # Firefox removed: Zen (main) + Chromium (secondary) replace it.
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
}
