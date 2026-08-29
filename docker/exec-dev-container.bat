@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem exec-dev-container.bat
rem
rem Opens an interactive bash shell inside the running dev container via
rem "docker exec". This is the supported way to connect to the container
rem (SSH is not used; see ../README.md).
rem ============================================================================

set "DISTRO=Debian"
set "RESULT=0"

where wsl.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] wsl.exe not found. Is WSL installed?
    set "RESULT=1"
    goto :end
)

wsl.exe -d %DISTRO% -- bash -lc "docker ps --filter name=dev-container --filter status=running -q | grep -q ." >nul 2>nul
if errorlevel 1 (
    echo [ERROR] The dev-container is not running.
    echo         Start it first with start-dev-container.bat.
    set "RESULT=1"
    goto :end
)

echo [INFO] Attaching to dev-container ...
wsl.exe -d %DISTRO% -- docker exec -it dev-container bash
set "RESULT=%ERRORLEVEL%"

:end
echo.
pause
exit /b %RESULT%
