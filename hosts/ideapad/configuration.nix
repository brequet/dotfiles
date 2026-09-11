# Host "ideapad" — Lenovo IdeaPad Pro 5 14AHP9, NixOS + Windows dual boot.
# Rebuild:   sudo nixos-rebuild switch --flake ~/dotfiles#ideapad
# Rollback:  sudo nixos-rebuild switch --rollback
{
  config, pkgs, zen-browser, nixpkgs-unstable, ...
}:

let
  unstable = nixpkgs-unstable.legacyPackages.${pkgs.system};
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

  # Windows keeps the RTC on local time; without this the clock jumps per OS switch.
  time.hardwareClockInLocalTime = true;

  # fish as the interactive shell
  programs.fish.enable = true;
  users.users.brequet.shell = pkgs.fish;

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
    packages = with pkgs; [
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
    ];
  };

  # Firefox removed: Zen (main) + Chromium (secondary) replace it.
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
}
