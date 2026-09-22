@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem exec.bat
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

wsl.exe -d %DISTRO% -- bash -lc "docker ps --filter name=general-develop --filter status=running -q | grep -q ." >nul 2>nul
if errorlevel 1 (
    echo [ERROR] The general-develop container is not running.
    echo         Start it first with start.bat.
    set "RESULT=1"
    goto :end
)

echo [INFO] Attaching to general-develop ...
wsl.exe -d %DISTRO% -- docker exec -it general-develop bash
set "RESULT=%ERRORLEVEL%"

:end
echo.
pause
exit /b %RESULT%
