{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in

{
  home.stateVersion = "26.05";

  # Binaries built outside Nix (`cargo install`) land in ~/.cargo/bin;
  # NixOS doesn't add that directory to PATH on its own.
  home.sessionPath = [ "$HOME/.cargo/bin" ];

  # fiche reads the vault location from the environment; it's not a secret,
  # so it can be set declaratively here.
  home.sessionVariables.FICHE_VAULT_PATH = "${config.home.homeDirectory}/Documents/vault";

  # Symlinked out of the store so Zed's settings editor writes through to the
  # repo working copy; only Nix changes need a rebuild.
  xdg.configFile = {
    "zed/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/zed/settings.json";
    "zed/keymap.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/zed/keymap.json";
    "starship.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/starship/starship.toml";
    # Same for the niri session config.
    "niri/config.kdl".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/niri/config.kdl";
    # The generated hm-session-vars script skips itself when this marker is
    # inherited (e.g. imported into the systemd user environment by some app),
    # which would leave PATH and session variables unapplied in fish. conf.d is
    # sourced before config.fish, so clear the marker before that happens.
    "fish/conf.d/hm-session-vars-marker.fish".text = ''
      set -e __HM_SESS_VARS_SOURCED
    '';
  };

  # Global opencode config, versioned in the repo and editable in place.
  xdg.configFile."opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/agents/AGENTS.md";
  xdg.configFile."opencode/opencode.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/opencode/opencode.jsonc";

  # Same out-of-store trick so skills stay editable in place while being
  # versioned in this repo.
  home.file.".agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home/agents/skills";

  # OpenChamber rewrites preferences.json atomically (temp file + rename), so a
  # symlink would be replaced by a regular file on every save. Seed it on a
  # fresh install instead and leave the live file under the app's control.
  home.activation.openchamberPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e "$HOME/.config/openchamber/preferences.json" ]]; then
      run mkdir -p -m 700 "$HOME/.config/openchamber"
      run install -m 600 ${./openchamber/preferences.json} "$HOME/.config/openchamber/preferences.json"
    fi
  '';

  catppuccin = {
    enable = true;
    # Explicitly true to match `enable` and silence catppuccin/nix's
    # deprecation notice; when autoEnable was unset it defaulted to `enable`.
    autoEnable = true;
    flavor = "mocha";
    accent = "mauve";
    cursors.enable = true;
    # The starship port generates ~/.config/starship.toml; we manage that file
    # ourselves from the repo instead.
    starship.enable = false;
  };

  programs = {
    fish.enable = true;
    # fiche needs OPENCODE_API_KEY; ask for it once (home/fiche/ensure-api-key.sh)
    # and load it from outside the Nix store on every shell.
    fish.shellInit = ''
      if test -s ~/.config/fiche/api_key
        set -gx OPENCODE_API_KEY (cat ~/.config/fiche/api_key)
      else if status is-interactive
        bash ${./fiche/ensure-api-key.sh}
        if test -s ~/.config/fiche/api_key
          set -gx OPENCODE_API_KEY (cat ~/.config/fiche/api_key)
        end
      end
    '';
    starship = {
      enable = true;
      enableTransience = true;
    };
    ghostty = {
      enable = true;
      settings = {
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12;
      };
    };
    btop.enable = true;
    yazi.enable = true;
    bat.enable = true;
    eza.enable = true;
    helix.enable = true;
    zoxide.enable = true;
    fzf.enable = true;
    fd.enable = true;
    gh.enable = true;
    # Host aliases only, no secrets (the private keys stay outside the repo
    # under ~/.ssh). `win` is the alias the tv-windows-laptop skill uses.
    # `enableDefaultConfig` is going away upstream, so the defaults it used
    # to inject are spelled out below (same values OpenSSH itself uses).
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          ForwardAgent = false;
          AddKeysToAgent = "no";
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };
        win = {
          HostName = "192.168.1.67";
          User = "batbo";
          IdentityFile = "~/.ssh/id_ed25519";
        };
        oracle = {
          HostName = "144.24.193.235";
          User = "opc";
          IdentityFile = "~/.ssh/oracle_ssh-key-2022-05-30.key";
        };
      };
    };
    # Global identity only. Git also reads a legacy ~/.gitconfig which
    # overrides this file, so delete it after the switch that writes
    # ~/.config/git/config.
    git = {
      enable = true;
      settings.user = {
        name = "brequet";
        email = "requet.baptiste@gmail.com";
      };
    };
    # Vicinae launcher (raycast-like), bound on Mod+Space. Target niri.service
    # so its daemon only runs in the niri session.
    vicinae = {
      enable = true;
      systemd = {
        enable = true;
        target = "niri.service";
      };
    };
    # Noctalia shell for the niri session. Its systemd unit is hand-wired in
    # the host config: the HM module's unit targets graphical-session.target,
    # which would start it in any graphical session.
    # Settings land in ~/.config/noctalia/config.toml; the Settings GUI keeps
    # writing runtime overrides to ~/.local/state/noctalia/settings.toml.
    noctalia = {
      enable = true;
      settings = {
        shell.font = "JetBrainsMono Nerd Font";
        # Noctalia becomes the polkit agent in the niri session.
        shell.polkit_agent = true;
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
        # Noctalia notes: full-height side panel of plain .md files that lives
        # inside the synced Obsidian vault (folder itself set in Settings ->
        # Plugins, the gear on the notes row; per-file location is runtime
        # state, not declarative config).
        plugins.enabled = [ "noctalia/notes" ];
      };
    };
  };

  home.packages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    chromium
    # Wayland helpers; Noctalia provides the bar, notifications, tray and
    # mixer, Vicinae is the launcher, Noctalia the brightness OSD.
    xwayland-satellite
    obsidian
    ripgrep
    unstable.opencode
    openchamber
    package-version-server
    # Nix language server, used by the Zed Nix extension.
    nixd
  ];
}
