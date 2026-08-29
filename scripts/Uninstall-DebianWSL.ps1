<#
.SYNOPSIS
    Completely uninstalls the installed Debian WSL distribution.

.DESCRIPTION
    Performs the following steps in order:
      1. Unregisters the target WSL distribution (wsl --unregister).
         This permanently deletes the distribution, including its
         virtual disk and file system. This action cannot be undone.
      2. Uninstalls the corresponding Microsoft Store app package (Debian).

    This script assumes execution via powershell.exe (Windows PowerShell 5.1).
    It has not been tested with pwsh.exe (PowerShell 7 / PowerShell Core).

.PARAMETER DistroName
    Name of the WSL distribution to uninstall. Defaults to "Debian".

.PARAMETER Force
    Skip confirmation prompts and run non-interactively.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-DebianWSL.ps1

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-DebianWSL.ps1 -Force
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
    Write-Error "wsl.exe was not found. Windows Subsystem for Linux may not be enabled."
    exit 1
}

Write-Section "Currently installed WSL distributions"
wsl.exe --list --verbose

# --- Check whether the target distribution exists ---
# wsl --list --quiet output may contain stray NUL characters from UTF-16 encoding, so strip them.
$distroList = (wsl.exe --list --quiet) | ForEach-Object { $_ -replace "`0", "" } | Where-Object { $_.Trim() -ne "" }
$distroExists = $distroList | Where-Object { $_.Trim() -eq $DistroName }

if (-not $distroExists) {
    Write-Warning "WSL distribution '$DistroName' was not found. Skipping unregister step."
} else {
    if (-not $Force) {
        $answer = Read-Host "This will permanently uninstall WSL distribution '$DistroName' (data cannot be recovered). Continue? (y/N)"
        if ($answer -notmatch '^(y|Y)$') {
            Write-Host "Aborted." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Section "Unregistering WSL distribution '$DistroName'"
    wsl.exe --unregister $DistroName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "wsl --unregister $DistroName failed. (exit code: $LASTEXITCODE)"
        exit 1
    }
    Write-Host "'$DistroName' has been unregistered (its disk data was also deleted)." -ForegroundColor Green
}

# --- Uninstall the Microsoft Store app package for Debian ---
Write-Section "Checking Microsoft Store app packages"
$appxPackages = Get-AppxPackage -Name "*$DistroName*" -ErrorAction SilentlyContinue

if (-not $appxPackages) {
    Write-Host "No matching Microsoft Store app package was found." -ForegroundColor Yellow
} else {
    foreach ($pkg in $appxPackages) {
        if (-not $Force) {
            $answer = Read-Host "Uninstall app package '$($pkg.Name)'? (y/N)"
            if ($answer -notmatch '^(y|Y)$') {
                Write-Host "Skipped uninstalling '$($pkg.Name)'." -ForegroundColor Yellow
                continue
            }
        }
        Write-Host "Uninstalling app package '$($pkg.Name)'..." -ForegroundColor Cyan
        Remove-AppxPackage -Package $pkg.PackageFullName
        Write-Host "'$($pkg.Name)' has been uninstalled." -ForegroundColor Green
    }
}

Write-Section "Done"
Write-Host "Debian WSL removal process has finished." -ForegroundColor Green
Write-Host "Current WSL distribution list:" -ForegroundColor Cyan
wsl.exe --list --verbose
