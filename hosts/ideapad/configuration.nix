# Host "ideapad" — Lenovo IdeaPad Pro 5 14AHP9, NixOS + Windows dual boot.
# Rebuild:   sudo nixos-rebuild switch --flake ~/dotfiles#ideapad
# Rollback:  sudo nixos-rebuild switch --rollback
{
  config, inputs, pkgs, zen-browser, nixpkgs-unstable, ...
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
    forceInstall = true;
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

  # os-prober is a separate package; grub needs it to find the Windows entry.
  # efibootmgr: manage UEFI boot order (dual boot).
  environment.systemPackages = with pkgs; [ git os-prober efibootmgr zed-editor ghostty ];

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

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
