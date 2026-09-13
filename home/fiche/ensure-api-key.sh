#!/usr/bin/env bash
# Ask once for the OpenCode API key and store it outside the Nix store, in
# ~/.config/fiche/api_key (mode 600). fish sources it at startup, so the key
# is never written into the world-readable Nix store or the dotfiles repo.
set -euo pipefail

key_file="${XDG_CONFIG_HOME:-$HOME/.config}/fiche/api_key"

if [ -s "$key_file" ]; then
  exit 0
fi

if [ ! -t 0 ]; then
  echo "fiche: no OpenCode API key at $key_file; run this script from a terminal to set it." >&2
  exit 1
fi

printf 'OpenCode API key for fiche (input hidden, stored at %s): ' "$key_file" >&2
if ! IFS= read -r -s key; then
  echo >&2
  echo "Aborted." >&2
  exit 1
fi
echo >&2

mkdir -p "$(dirname "$key_file")"
umask 077
printf '%s\n' "$key" > "$key_file"
unset key

echo "Saved. New shells will export OPENCODE_API_KEY automatically." >&2
