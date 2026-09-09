@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem start-dev-container.bat
rem
rem Starts the dev container by running "docker compose up -d --build"
rem from inside the WSL Debian distribution.
rem
rem Background: Rancher Desktop's docker client cannot resolve UNC paths like
rem \\wsl$\Debian\... as a bind mount source (known limitation, see
rem ../README.md). So instead of calling docker/docker compose directly from
rem Windows, this script enters the WSL Debian shell via wsl.exe and runs
rem docker compose there, using Debian's native filesystem path.
rem
rem Before starting, it regenerates compose.host-drives.yaml by running
rem scripts/generate-host-drives-compose.sh, which dynamically detects which
rem host drives (C:, D:, ...) are actually mounted under /mnt in WSL Debian
rem and defines one bind mount per drive. This avoids bind-mounting /mnt as a
rem whole (which used to fail with "munger failed ... could not unmount bind
rem mount ... invalid argument" on container recreation because /mnt itself
rem contains nested per-drive mount points; see docs/BACKGROUND.md).
rem
rem It also runs scripts/mount-network-drives.sh as root (via wsl.exe -u root,
rem which does not require a password) to dynamically detect and mount any
rem Windows-mapped network drives (e.g. Z:) under /mnt, since WSL only
rem auto-mounts local/fixed drives on boot. This avoids hardcoding a specific
rem drive letter; see docs/BACKGROUND.md.
rem ============================================================================

set "DISTRO=Debian"
set "SCRIPT_DIR=%~dp0"
set "RESULT=0"

if not exist "%SCRIPT_DIR%config\.env" (
    echo [ERROR] %SCRIPT_DIR%config\.env not found.
    echo         Copy config\.env.example to config\.env and set WSL_MOUNT_SOURCE etc.
    echo         Example: copy config\.env.example config\.env
    set "RESULT=1"
    goto :end
)

where wsl.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] wsl.exe not found. Is WSL installed?
    set "RESULT=1"
    goto :end
)

echo [INFO] Detecting and mounting Windows-mapped network drives (as root)...
wsl.exe -d %DISTRO% -u root -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%')\" && bash scripts/mount-network-drives.sh"
if errorlevel 1 (
    echo [WARN] Failed to mount network drives. Continuing without them, see log above.
)

echo [INFO] Detecting host drives inside WSL Debian...
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%')\" && bash scripts/generate-host-drives-compose.sh"
if errorlevel 1 (
    echo [ERROR] Failed to generate host-drives compose override. See the log above.
    set "RESULT=1"
    goto :end
)

echo [INFO] Running "docker compose up -d --build" inside WSL Debian...
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%config')\" && docker compose -f compose.yaml -f compose.host-drives.yaml up -d --build"
if errorlevel 1 (
    echo [ERROR] docker compose up failed. See the log above.
    set "RESULT=1"
    goto :end
)

echo.
echo [INFO] Started. Run "docker compose ps" inside the WSL Debian shell to check status.

:end
echo.
pause
exit /b %RESULT%
