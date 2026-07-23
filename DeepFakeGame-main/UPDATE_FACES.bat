@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0UPDATE_FACES.ps1"
echo.
echo You can now open index.html.
pause
