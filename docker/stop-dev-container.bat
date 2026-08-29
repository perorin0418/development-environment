@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem stop-dev-container.bat
rem
rem Removes the dev container by running "docker compose down" from inside the
rem WSL Debian distribution.
rem
rem The container itself is deleted (the image is kept), so restarting it with
rem start-dev-container.bat will recreate it from scratch. This is safe:
rem project files (WSL_MOUNT_SOURCE) and credentials/config (WSL_JCODE_HOME,
rem WSL_GH_CONFIG_HOME, WSL_CLAUDE_HOME, WSL_SSH_HOME, WSL_GITCONFIG_FILE,
rem WSL_NPMRC_FILE) are bind-mounted from WSL Debian and are not affected by
rem "docker compose down" (see ../docs/PERSISTENCE.md).
rem ============================================================================

set "DISTRO=Debian"
set "SCRIPT_DIR=%~dp0"
set "RESULT=0"

where wsl.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] wsl.exe not found. Is WSL installed?
    set "RESULT=1"
    goto :end
)

echo [INFO] Running "docker compose down" inside WSL Debian...
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%')\" && docker compose down"
if errorlevel 1 (
    echo [ERROR] docker compose down failed. See the log above.
    set "RESULT=1"
    goto :end
)

echo.
echo [INFO] Removed. Run start-dev-container.bat to recreate and start again.

:end
echo.
pause
exit /b %RESULT%
