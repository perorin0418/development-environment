@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem stop-dev-container.bat
rem
rem Stops the dev container by running "docker compose stop" from inside the
rem WSL Debian distribution.
rem
rem The container and its network are kept (not removed), so it can be
rem resumed with start-dev-container.bat. To remove the container entirely,
rem run "docker compose down" inside the WSL Debian shell.
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

echo [INFO] Running "docker compose stop" inside WSL Debian...
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%')\" && docker compose stop"
if errorlevel 1 (
    echo [ERROR] docker compose stop failed. See the log above.
    set "RESULT=1"
    goto :end
)

echo.
echo [INFO] Stopped. Run start-dev-container.bat to resume.

:end
echo.
pause
exit /b %RESULT%
