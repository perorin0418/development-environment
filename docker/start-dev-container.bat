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

echo [INFO] Running "docker compose up -d --build" inside WSL Debian...
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%config')\" && docker compose up -d --build"
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
