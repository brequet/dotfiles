---
name: tv-windows-laptop
description: Interact with the TV Windows laptop (DESKTOP-EENFCL6, 192.168.1.67) over SSH. Use whenever the user mentions the TV laptop, TV PC, Windows laptop, DESKTOP-EENFCL6, 192.168.1.67, or asks to run commands, inspect, copy files, reboot, or manage anything on that Windows machine.
---

# TV Windows laptop

Windows machine on the home LAN, used connected to the TV. All interaction is
over SSH with a key; the remote shell is PowerShell 7. SSH access was set up
on 2026-09-12 and must not need a password.

## Identity

| | |
|---|---|
| Hostname | `DESKTOP-EENFCL6` |
| LAN address | `192.168.1.67` (LAN is `192.168.1.0/24`) |
| SSH user | `batbo` — administrator, so SSH sessions are elevated |
| OS | Windows, workgroup `WORKGROUP`, TTL 128 |
| MAC | `F8:34:41:B5:57:52` |
| Remote shell | PowerShell 7.6.x (`pwsh`), default cwd `C:\Users\batbo` |
| SSH server | `OpenSSH_for_Windows_9.5` on port 22 |

## Access

Always use the `win` alias from `~/.ssh/config` (user `batbo`, key
`~/.ssh/id_ed25519`):

```bash
ssh win hostname
ssh win 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 5'
scp win:C:/Users/batbo/Desktop/file.txt .
scp localfile.txt win:C:/Users/batbo/Desktop/
```

- Key-based auth is configured. **Never ask for or look up the Windows
  password** (e.g. don't read fish variables or credential files for it); the
  key is the supported path. If key auth breaks, ask the user to fix access.
- Fallback if the alias is missing: `ssh batbo@192.168.1.67`; the host key is
  already trusted in `known_hosts`.
- The key is installed in `C:\ProgramData\ssh\administrators_authorized_keys`
  (Windows reads only this file for administrator accounts) and as a fallback
  in `C:\Users\batbo\.ssh\authorized_keys`. The admin file's ACL must stay
  exactly `SYSTEM:F` + `Administrators:F`; sshd rejects it if other users can
  write it.

## Running things remotely

- The default shell is **PowerShell**, not cmd: use `;` or `&&` (PS7), cmdlets
  instead of cmd builtins, and `$env:VAR` instead of `%VAR%`.
- `&` in PowerShell is the background-job operator — avoid it; quote the whole
  remote command as one argument: `ssh win 'Get-ChildItem C:\'`.
- Interactive/TUI programs don't work non-interactively. Prefer
  non-interactive forms (`Get-Content`, `Export-Csv`, flags).
- Windows paths use backslashes; for scp/sftp use forward slashes
  (`win:C:/Users/batbo/...`).
- Output over SSH is UTF-16-ish with NUL bytes and ANSI color, so `grep` may
  report "binary file matches". Filter with `tr -cd '\11\12\15\40-\176'`, and
  in PowerShell add
  `if ($PSVersionTable.PSVersion.Major -ge 7) { $PSStyle.OutputRendering = "PlainText" }`
  to suppress color. The ssh client also prints `** WARNING ... post-quantum`
  lines; drop them with `grep -v '^\*\* '`.
- Commands run **elevated** (batbo is an admin): destructive or system
  changes take effect immediately. Reboot/shutdown only on explicit request.

Useful checks:

```bash
ssh win 'hostname; whoami'                                   # connectivity
ssh win 'Get-Service | Where-Object Status -eq "Running"'
ssh win 'Get-Volume | Select-Object DriveLetter, SizeRemaining'
```

## Troubleshooting

- `Permission denied (publickey)` → key missing from
  `administrators_authorized_keys` or its ACL is wrong.
- Host unreachable → check the laptop is powered on with `ping 192.168.1.67`.
- Fallbacks exist but SSH is preferred: WinRM on port 5985, SMB on 445.
- RDP (3389) is closed; don't suggest it.
