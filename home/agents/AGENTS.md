# Global context

- This machine is the NixOS 26.05 side of a dual-boot laptop (host `ideapad`; Windows on the other partition).
- The user is a NixOS beginner learning it and wants it to become their daily driver. Prefer simple, idiomatic Nix over clever abstractions, and briefly explain unfamiliar Nix concepts when they matter.
- My projects are at $HOME/Projects/

# Working rules

- Persistent changes live in `~/dotfiles`, never in the live paths under `~`, `/etc`, or `/nix/store`. Its layout and workflow are documented in `~/dotfiles/AGENTS.md`.
- The user is the one to run the commands that apply changes. Ask before anything touching boot, kernel, users, disks, or the Nix store: `nixos-rebuild`, `nix-collect-garbage`, `nix flake update`, `nixos-generate-config`.
- Read-only Nix commands are fine: `nix search`, `nix flake show`, `nixos-rebuild --dry-run`, `nix why-depends`.
- Install tools via `nix shell nixpkgs#pkg` or `nix run` for one-offs, and via `home.packages` for anything lasting. Avoid `nix-env` / `nix profile install`.
- Global opencode config is `~/.config/opencode/`; global skills are `~/.agents/skills`.

# Communication

- Be concise and direct; skip preamble and summaries.
- Show exact commands instead of describing them.
- Warn when a step needs a rebuild, reboot, or sudo before suggesting it.
