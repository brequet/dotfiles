#!/usr/bin/env bash
# Ask once for the OpenCode API key and store it outside the Nix store, in
# ~/.secrets/opencode-api-key (mode 600). fish exports it at login as
# OPENCODE_API_KEY, which opencode, fiche and OpenChamber all read.
set -euo pipefail

key_file="$HOME/.secrets/opencode-api-key"

if [ -s "$key_file" ]; then
  exit 0
fi

if [ ! -t 0 ]; then
  echo "opencode: no API key at $key_file; run this script from a terminal to set it." >&2
  exit 1
fi

printf 'OpenCode API key for opencode/fiche (input hidden, stored at %s): ' "$key_file" >&2
if ! IFS= read -r -s key; then
  echo >&2
  echo "Aborted." >&2
  exit 1
fi
echo >&2

umask 077
mkdir -p "$(dirname "$key_file")"
chmod 700 "$(dirname "$key_file")"
printf '%s\n' "$key" > "$key_file"
chmod 600 "$key_file"
unset key

echo "Saved. New fish shells export OPENCODE_API_KEY; log out/in (or run 'systemctl --user import-environment OPENCODE_API_KEY' in a fresh shell) so GUI apps see it." >&2
