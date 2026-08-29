@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem setup-dev-container.bat
rem
rem One-time setup to run before start-dev-container.bat. Runs
rem scripts\setup-dev-container.sh inside WSL Debian, which:
rem   - creates .env from .env.example if missing (defaults work out of the box)
rem   - disables the docker credential helper (avoids known WSL PATH interop
rem     issues, see ../docs/BACKGROUND.md)
rem   - creates the bind-mount source directories/files declared in .env and
rem     fixes their ownership (avoids the permission-denied crash loop
rem     described in ../docs/TROUBLESHOOTING.md)
rem
rem Safe to re-run any time, e.g. after editing .env.
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

echo [INFO] Running one-time setup inside WSL Debian...
echo        (may ask for your WSL Debian password via sudo)
wsl.exe -d %DISTRO% -- bash -lc "cd \"$(wslpath -a '%SCRIPT_DIR%')\" && bash scripts/setup-dev-container.sh"
if errorlevel 1 (
    echo [ERROR] Setup failed. See the log above.
    set "RESULT=1"
    goto :end
)

echo.
echo [INFO] Setup complete.
echo        Next: run start-dev-container.bat.
echo        (If you want a custom project folder, edit .env now and re-run this script.)

:end
echo.
pause
exit /b %RESULT%
