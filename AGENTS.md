# Dotfiles repo

Source of truth for all system and home configuration (flake at root).

- `flake.nix` / `flake.lock` — inputs and host outputs.
- `hosts/ideapad/` — NixOS system config for this host.
- `home/brequet.nix` — home-manager config; hand-editable files live under `home/`.
- `pkgs/` — hand-pinned package definitions; `update.sh` refreshes them and rebuilds.

# Rules

- Edit files here; never the live paths under `~`, `/etc/nixos`, or `/nix/store`. `/etc/nixos` is legacy — move anything useful into this repo instead.
- Hand-editable configs are symlinked out of the store with `mkOutOfStoreSymlink` (the `link` helper in `home/brequet.nix`); follow that pattern instead of copying files or hardcoding store paths.
- Opencode files land here: `home/agents/AGENTS.md` → `~/.config/opencode/AGENTS.md`, `home/opencode/opencode.jsonc` → `~/.config/opencode/opencode.jsonc`, `home/agents/skills/` → `~/.agents/skills`.
- The user runs commands that apply changes (`nixos-rebuild`); ask before boot/kernel/users/disks/store commands and suggest the exact command. Read-only Nix commands are fine.
- Nix files are formatted with `nix fmt` (nixfmt, RFC style). `.githooks/pre-commit` formats staged `.nix` files on commit; enable it once per clone with `git config core.hooksPath .githooks` (bypass: `git commit --no-verify`).
- When a fix works, suggest adding and committing it here.
