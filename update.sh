#!/usr/bin/env bash
# Update everything in one go:
#   1. every flake input (nixpkgs, nixpkgs-unstable, home-manager, ...)
#   2. the hand-pinned packages in pkgs/ (flake update never touches those)
#   3. the system itself
# Afterwards review the changes with `git -C ~/dotfiles diff` and commit.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo"

echo "==> Updating flake inputs"
nix flake update

echo "==> Updating openchamber"
nix run nixpkgs#nix-update -- --flake openchamber

echo "==> Updating opencode"
nix run nixpkgs#nix-update -- --flake opencode

echo "==> Rebuilding ideapad"
sudo nixos-rebuild switch --flake "$repo#ideapad"

echo
echo "Done. Review the changes with: git -C \"$repo\" diff"
