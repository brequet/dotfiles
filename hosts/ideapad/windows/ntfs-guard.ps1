# Keeps hibernation and Fast Startup off on Windows so the shared NTFS
# partition is always closed cleanly at shutdown. A hibernated volume makes
# Linux NTFS drivers refuse read-write mounts; forcing one corrupts the
# filesystem.
#
# Deployed as the scheduled task "ntfs-guard" (At startup, SYSTEM,
# RunLevel Highest). Install with:
#   Register-ScheduledTask -TaskName ntfs-guard `
#     -Action (New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\dev\projects\dotfiles\hosts\ideapad\windows\ntfs-guard.ps1"') `
#     -Trigger (New-ScheduledTaskTrigger -AtStartup) `
#     -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) `
#     -Settings (New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries) `
#     -Description 'Keep hibernation and Fast Startup off to protect the shared NTFS partition'

$ErrorActionPreference = 'Stop'

$logDir = Join-Path $env:ProgramData 'ntfs-guard'
$logFile = Join-Path $logDir 'ntfs-guard.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Write-Log {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" | Add-Content -LiteralPath $logFile
}

$bootKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$powerKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
$hiberfile = Join-Path $env:SystemDrive 'hiberfil.sys'

try {
    $changed = $false

    $hiberboot = (Get-ItemProperty -LiteralPath $bootKey -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($hiberboot -ne 0) {
        New-ItemProperty -LiteralPath $bootKey -Name HiberbootEnabled -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Log "Fast Startup was on (HiberbootEnabled=$hiberboot); disabled."
        $changed = $true
    }

    $hiberEnabled = (Get-ItemProperty -LiteralPath $powerKey -Name HibernateEnabled -ErrorAction SilentlyContinue).HibernateEnabled
    if ($hiberEnabled -eq 1 -or (Test-Path -LiteralPath $hiberfile)) {
        $output = & powercfg.exe /h off 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "powercfg /h off failed with exit code $LASTEXITCODE`: $output"
        }
        Write-Log 'Hibernation was on; disabled (hiberfil.sys removed).'
        $changed = $true
    }

    $hiberboot = (Get-ItemProperty -LiteralPath $bootKey -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    $hiberEnabled = (Get-ItemProperty -LiteralPath $powerKey -Name HibernateEnabled -ErrorAction SilentlyContinue).HibernateEnabled
    if ($hiberboot -ne 0 -or $hiberEnabled -eq 1) {
        throw "Verification failed: HiberbootEnabled=$hiberboot, HibernateEnabled=$hiberEnabled."
    }
    if (Test-Path -LiteralPath $hiberfile) {
        throw "Verification failed: $hiberfile still exists."
    }

    if ($changed) {
        Write-Log 'Guard applied.'
    } else {
        Write-Log 'Already compliant.'
    }
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
