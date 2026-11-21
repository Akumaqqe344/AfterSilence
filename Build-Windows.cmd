@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows\build.ps1" %*
set "result=%ERRORLEVEL%"
if "%~1"=="" pause
exit /b %result%
