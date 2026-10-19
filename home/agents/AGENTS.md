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

# Secrets

Secrets: API keys, tokens, passwords, private keys, connection strings, and anything in `.env` files.

## Never

- Ask me to paste a secret in chat.
- Read secret files (`.env*`, `*.pem`, `*.key`, credential files). This covers every tool: Read, cat, type, grep, Get-Content.
- Print, echo, or log a secret value.
- Write a secret into code, config, tests, commits, or command arguments.
- Repeat a secret in summaries, errors, or tool output.

## Always

- Use secrets by reference only: environment variables, secret managers, or stdin pipes.
- Check that a secret exists without showing it.
- Let tools load secrets themselves.
- Keep `.env` in `.gitignore`.
- Load a secret file only inside a command whose output is never shown. Never run `cat` or `echo` on it alone.
- Never use `set -x`, `curl -v`, or any debug flag that prints headers.
- Secret files live in `~/.secrets/<service>-<name>`. If a task needs one, check for a matching skill first.

test -s ~/.secrets/dokploy-token && echo set || echo missing

## If a secret is missing

Tell me the variable name and stop. I will set it in my own terminal. Give me the command so it prompt me and create the right file on my input.

## If you see a secret

1. Do not repeat it.
2. Tell me it was exposed.
3. Tell me to rotate it.
