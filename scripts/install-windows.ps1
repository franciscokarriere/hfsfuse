<#
.SYNOPSIS
    Installs hfsfuse as a WinFsp.Launcher service so HFS+ disks can be mapped from Windows Explorer.

.DESCRIPTION
    Copies hfsfuse.exe to "%ProgramFiles%\hfsfuse" and registers it under
    HKLM\SOFTWARE\WOW6432Node\WinFsp\Services\hfsfuse (same key fsreg.bat writes).

    Once installed, any signed-in user can mount a disk without an elevated terminal:
        net use M: \\hfsfuse\PhysicalDrive3
    or Explorer > This PC > Map network drive > Folder: \\hfsfuse\PhysicalDrive3
    The file system runs as LocalSystem, which is allowed to read the raw disk.
    Unmount with "net use M: /delete" or Explorer > Disconnect.

    Must be run from an elevated PowerShell.

.PARAMETER Source
    hfsfuse.exe to install. Defaults to the one built in the repository root.

.PARAMETER AllowDirtyJournal
    Pass --force to hfsfuse so volumes with a dirty journal (not ejected cleanly) are mounted anyway.
    Read-only mounts are not damaged by this, but changes still in the journal won't be visible.

.PARAMETER Uninstall
    Removes the launcher registration and the installed files.
#>
[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot "..\hfsfuse.exe"),
    [switch]$AllowDirtyJournal,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run from an elevated PowerShell (Run as administrator)."
}

$serviceName = "hfsfuse"
$serviceKey  = "HKLM:\SOFTWARE\WOW6432Node\WinFsp\Services\$serviceName"
$installDir  = Join-Path $env:ProgramFiles "hfsfuse"
$installExe  = Join-Path $installDir "hfsfuse.exe"

if ($Uninstall) {
    if (Test-Path $serviceKey) { Remove-Item $serviceKey -Recurse -Force }
    if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
    Write-Host "hfsfuse launcher service removed."
    return
}

if (-not (Test-Path "HKLM:\SOFTWARE\WOW6432Node\WinFsp")) {
    throw "WinFsp is not installed. Install it from https://winfsp.dev/rel/ first."
}
if (-not (Test-Path $Source)) {
    throw "hfsfuse.exe not found at '$Source'. Build it first with scripts/build-windows.sh."
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item -Force $Source $installExe

# %1 = UNC path mapped by the user (\\hfsfuse\PhysicalDriveN), %2 = drive letter
$commandLine = "%1 %2"
if ($AllowDirtyJournal) { $commandLine += " --force" }

New-Item -Force -Path $serviceKey | Out-Null
Set-ItemProperty -Path $serviceKey -Name Executable  -Value $installExe -Type String
Set-ItemProperty -Path $serviceKey -Name CommandLine -Value $commandLine -Type String
Set-ItemProperty -Path $serviceKey -Name JobControl  -Value 1 -Type DWord
# Allow authenticated users to start (RP), stop (WP) and query (LC) hfsfuse instances
Set-ItemProperty -Path $serviceKey -Name Security    -Value "D:P(A;;RPWPLC;;;AU)" -Type String

Write-Host "hfsfuse installed to $installExe"
Write-Host "Mount from a normal (non-elevated) session with:"
Write-Host "    net use M: \\hfsfuse\PhysicalDriveN"
Write-Host "Find N with: Get-Disk"
