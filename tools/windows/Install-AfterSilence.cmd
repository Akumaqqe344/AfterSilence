@echo off
setlocal
if not exist "%~dp0install.ps1" (
    echo Extract all files from the ZIP before running this installer.
    pause
    exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "result=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %result%
