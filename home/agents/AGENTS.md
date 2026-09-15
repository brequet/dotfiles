# Global context

- This machine is the NixOS 26.05 side of a dual-boot laptop (host `ideapad`; Windows on the other partition).
- The user is a NixOS beginner learning it and wants it to become their daily driver. Prefer simple, idiomatic Nix over clever abstractions, and briefly explain unfamiliar Nix concepts when they matter.

# Dotfiles are the source of truth

- All system and home configuration lives in `~/dotfiles` (flake at root; `hosts/ideapad/`, `home/brequet.nix`). Never edit `/etc/nixos` or anything in `/nix/store`.
- Apply changes with: `sudo nixos-rebuild switch --flake ~/dotfiles#ideapad`
- Hand-editable configs are linked into place with `mkOutOfStoreSymlink`; follow that pattern instead of copying files or hardcoding paths in the store.
- Global opencode config lives in `~/.config/opencode/`; skills are `~/.agents/skills`, a symlink into `~/dotfiles/home/agents/skills`.

# Working rules

- To change anything persistent, edit `~/dotfiles`, not the live paths under `~`, `/etc`, or `/nix/store`.
- Ask before anything touching boot, kernel, users, disks, or the Nix store: `nixos-rebuild`, `nix-collect-garbage`, `nix flake update`, `nixos-generate-config`.
- Read-only Nix commands are fine: `nix search`, `nix flake show`, `nixos-rebuild --dry-run`, `nix why-depends`.
- Install tools via `nix shell nixpkgs#pkg` or `nix run` for one-offs, and via `home.packages` for anything lasting. Avoid `nix-env` / `nix profile install`.
- Nix files are formatted with `nix fmt` (nixfmt, RFC style). `.githooks/pre-commit` formats staged `.nix` files on commit; enable it once per clone with `git config core.hooksPath .githooks` (bypass with `git commit --no-verify`).
- When a fix works, suggest adding and committing it in `~/dotfiles`.

# Communication

- Be concise and direct; skip preamble and summaries.
- Show exact commands instead of describing them.
- Warn when a step needs a rebuild, reboot, or sudo before suggesting it.
