# Host "nixos" — Hyper-V test VM now, same file will drive the future dual-boot install.
# Rebuild:   sudo nixos-rebuild switch --flake /path/to/dotfiles/nixos#nixos
# Rollback:  sudo nixos-rebuild switch --rollback   (or pick old gen in boot menu)
{
  config, pkgs, zen-browser, ...
}:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot — systemd-boot while this is a plain VM.
  # DUAL BOOT (real laptop): comment the two lines below and enable the GRUB
  # block instead — the 100 MB Windows ESP is too small for systemd-boot kernels.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # boot.loader.systemd-boot.enable = false;
  # boot.loader.grub = {
  #   enable = true;
  #   device = "nodev";
  #   efiSupport = true;
  #   useOSProber = true; # auto-detects the Windows Boot Manager
  #   configurationLimit = 10;
  # };

  # Windows keeps the RTC on local time; without this the clock jumps per OS switch.
  time.hardwareClockInLocalTime = true;

  # Shared personal files partition, created from Windows (NTFS, label "DATA").
  # nofail: boots fine when the volume is absent (like in this VM).
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/DATA";
    fsType = "ntfs3";
    options = [ "nofail" "uid=1000" "gid=100" "windows_names" ];
  };

  virtualisation.hypervGuest.enable = true;

  services.openssh.enable = true;
  users.users.brequet.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyq3d3Y/KDA1A7W+1887m7GOo0RlK0n/EVdvw7+jbvF opencode-host"
  ];

  # True GNOME Wayland over RDP: gnome-remote-desktop in system/headless mode.
  # Connect from Windows with mstsc -> VM IP. Serves the real GNOME session
  # (not Xfce) with dynamic resolution + clipboard. Console keeps GNOME.
  services.gnome.gnome-remote-desktop.enable = true;
  systemd.services."gnome-remote-desktop".wantedBy = [ "graphical.target" ];
  networking.firewall.allowedTCPPorts = [ 3389 ];
  boot.kernelParams = [ "video=Virtual-1:1920x1080" ];

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

  environment.systemPackages = with pkgs; [ freerdp zed-editor ghostty ];

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # Realtek 8852CE (laptop) is unstable with Wi-Fi powersave enabled.
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

  # Bluetooth for the laptop's Realtek 8852CE combo (no-op in this VM).
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Firmware updates; TRIM for the NixOS partitions (Linux trims its own FS).
  services.fwupd.enable = true;
  services.fstrim.enable = true;

  # Compressed in-RAM swap: no disk swapfile, no hibernation (dual boot).
  zramSwap.enable = true;

  users.users.brequet = {
    isNormalUser = true;
    description = "brequet";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      zen-browser.packages."${pkgs.system}".default
      chromium
      obsidian
      opencode
      helix
      eza
      bat
      ripgrep
      yazi
      btop
    ];
  };

  # Firefox removed: Zen (main) + Chromium (secondary) replace it.
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
}
