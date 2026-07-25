@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "PS1=%SCRIPT_DIR%\WorkshopIconizer.ps1"

if not exist "%PS1%" (
    echo Could not find WorkshopIconizer.ps1 next to this .bat file.
    echo Both files need to be in the same folder.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    echo PowerShell was not found on this system. This tool requires Windows PowerShell.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -TargetDir "%SCRIPT_DIR%"
echo.
echo ---
echo Finished. This tool was created by Zanzah.com for free. Press any key to close this window.
pause >nul
exit /b %errorlevel%
