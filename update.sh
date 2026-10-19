#!/usr/bin/env bash
# Update everything in one go:
#   1. every flake input (nixpkgs, nixpkgs-unstable, home-manager, ...)
#   2. the hand-pinned packages in pkgs/ (flake update never touches those)
#   3. the system itself
# Afterwards review the changes with `git -C ~/dotfiles diff` and commit.
# Run as your user, not with sudo: root cannot read a git flake owned by you.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Do not run this script with sudo: only the final switch needs it." >&2
  echo "Run it as your user: ./update.sh" >&2
  exit 1
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo"

echo "==> Updating flake inputs"
nix flake update

echo "==> Updating openchamber"
nix run nixpkgs#nix-update -- --flake openchamber

echo "==> Updating opencode"
nix run nixpkgs#nix-update -- --flake opencode

echo "==> Rebuilding ideapad"
# Build as the user (who owns the git flake), then activate through sudo.
nixos-rebuild switch --sudo --flake "$repo#ideapad"

echo
echo "Done. Review the changes with: git -C \"$repo\" diff"
