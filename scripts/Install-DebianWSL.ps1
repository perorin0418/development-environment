<#
.SYNOPSIS
    Installs the Debian WSL distribution.

.DESCRIPTION
    Performs the following steps in order:
      1. Checks that wsl.exe is available.
      2. Checks whether the target distribution is already installed.
         If it is already installed, the install step is skipped.
      3. Runs `wsl --install -d <DistroName>` to install the distribution.
         On first launch, WSL prompts interactively for a UNIX username
         and password; this script does not automate that step.

    This script assumes execution via powershell.exe (Windows PowerShell 5.1).
    It has not been tested with pwsh.exe (PowerShell 7 / PowerShell Core).

.PARAMETER DistroName
    Name of the WSL distribution to install. Defaults to "Debian".

.PARAMETER Force
    Skip confirmation prompts and run non-interactively.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-DebianWSL.ps1

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Install-DebianWSL.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$DistroName = "Debian",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "==== $Message ====" -ForegroundColor Cyan
}

# --- Check that wsl.exe is available ---
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Error "wsl.exe was not found. Windows Subsystem for Linux may not be enabled on this machine."
    exit 1
}

Write-Section "Currently installed WSL distributions"
wsl.exe --list --verbose

# --- Check whether the target distribution is already installed ---
# wsl --list --quiet output may contain stray NUL characters from UTF-16 encoding, so strip them.
$distroList = (wsl.exe --list --quiet) | ForEach-Object { $_ -replace "`0", "" } | Where-Object { $_.Trim() -ne "" }
$distroExists = $distroList | Where-Object { $_.Trim() -eq $DistroName }

if ($distroExists) {
    Write-Warning "WSL distribution '$DistroName' is already installed. Skipping installation."
    exit 0
}

if (-not $Force) {
    $answer = Read-Host "Install WSL distribution '$DistroName'? (y/N)"
    if ($answer -notmatch '^(y|Y)$') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

Write-Section "Installing WSL distribution '$DistroName'"
Write-Host "A window may prompt you to create a UNIX username and password on first launch." -ForegroundColor Yellow
wsl.exe --install -d $DistroName
if ($LASTEXITCODE -ne 0) {
    Write-Error "wsl --install -d $DistroName failed. (exit code: $LASTEXITCODE)"
    Write-Host "If this is the first time WSL has been installed on this machine, a reboot may be required. Reboot and re-run this script." -ForegroundColor Yellow
    exit 1
}

Write-Section "Done"
Write-Host "'$DistroName' installation has finished." -ForegroundColor Green
Write-Host "If this is the first WSL installation on this machine, a reboot may be required before the distribution can be launched." -ForegroundColor Yellow
Write-Host "Current WSL distribution list:" -ForegroundColor Cyan
wsl.exe --list --verbose
