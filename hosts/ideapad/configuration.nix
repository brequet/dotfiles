# Host "ideapad" — Lenovo IdeaPad Pro 5 14AHP9, NixOS + Windows dual boot.
# Rebuild:   sudo nixos-rebuild switch --flake ~/dotfiles#ideapad
# Rollback:  sudo nixos-rebuild switch --rollback
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
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
  # Cache devshells so direnv doesn't re-evaluate the flake on every cd.
  programs.direnv.nix-direnv.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Local packages from pkgs/, exposed as pkgs.<name> to every module
  # (home-manager included, since it uses the global pkgs).
  nixpkgs.overlays = [ (import ../../pkgs) ];

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

  # dconf: GTK applications (zen, obsidian, file pickers) follow the system
  # color scheme and accent color from here.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          accent-color = "purple";
        };
      };
    }
  ];

  xdg.mime.defaultApplications = {
    "text/html" = "zen.desktop";
    "x-scheme-handler/http" = "zen.desktop";
    "x-scheme-handler/https" = "zen.desktop";
    "x-scheme-handler/about" = "zen.desktop";
    "x-scheme-handler/unknown" = "zen.desktop";
  };

  # System-wide packages only: efibootmgr manages UEFI boot order (dual boot)
  # and Zed is kept available outside the user session. git and ghostty are
  # installed by their home-manager modules. GRUB's installer pulls in
  # os-prober by itself when useOSProber is enabled, so we don't list it here.
  environment.systemPackages = with pkgs; [
    efibootmgr
    zed-editor
  ];

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

  # Login screen: Noctalia Greeter on greetd. It bundles its own wlroots
  # compositor (no per-greeter niri config needed) and lists every installed
  # session (niri). The module enables greetd, Polkit and
  # accounts-daemon (avatars). Wallpaper/palette/font are synced from the
  # Noctalia session through Polkit; brequet may apply that appearance-only
  # sync without typing a password.
  services.displayManager.noctalia-greeter = {
    enable = true;
    package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;
    passwordless-sync-users = [ "brequet" ];
    cursorTheme.package = pkgs.catppuccin-cursors.mochaMauve;
    settings = {
      session.default = "niri";
      keyboard.layout = "fr";
      cursor.theme = "catppuccin-mocha-mauve-cursors";
      cursor.size = 24;
    };
  };

  # Parse the hand-written niri config while the system is being built, so a
  # syntax error fails `nixos-rebuild` instead of the desktop session (learned
  # the hard way: `xkb { layout "fr" }` on one line is not valid KDL).
  # system.checks are build dependencies only and stay out of the closure.
  system.checks = [
    (pkgs.runCommand "niri-config-check" { nativeBuildInputs = [ config.programs.niri.package ]; } ''
      niri validate -c ${../../home/niri/config.kdl}
      touch $out
    '')
  ];

  programs.niri.enable = true;

  # Noctalia: a native C++/OpenGL ES shell for niri (bar, launcher, control
  # center, notifications, lock screen). Runs as a user service bound to
  # niri.service so it only starts with the niri session. Settings live in
  # programs.noctalia (home-manager).
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
  # UPower provides the D-Bus API Noctalia uses for the battery widget.
  services.upower.enable = true;

  # Suspend/resume: after a long s2idle the embedded controller is sometimes
  # slow to wake, which stalls the end of resume for seconds (12-16 s before
  # the NBCN32WW BIOS update, ~6 s occasionally after it). Two mitigations:
  # amd_pmc gives the EC 2.5 s to settle before sleeping, and systemd-sleep
  # no longer freezes user.slice, so a residual stall stops freezing the
  # whole session while the kernel finishes. Safe here: no LUKS home, no NFS.
  boot.extraModprobeConfig = "options amd_pmc delay_suspend=1";
  systemd.services.systemd-suspend.serviceConfig.Environment =
    "SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=0";

  # TTY keyboard layout. The graphical layouts live in their own configs:
  # niri's in ~/dotfiles/home/niri, the greeter's in the greeter settings.
  console.keyMap = "fr";

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
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Move pre-existing files to <file>.bak on first activation instead of
    # failing with a collision error.
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs; };
    sharedModules = [
      inputs.catppuccin.homeModules.catppuccin
      inputs.noctalia.homeModules.default
    ];
    users.brequet = import ../../home/brequet.nix;
  };

  # Obsidian is the only unfree package in use. Naming it here means anything
  # else unfree fails the build instead of being silently allowed.
  nixpkgs.config.allowUnfreePackages = [ "obsidian" ];

  system.stateVersion = "26.05";
}
