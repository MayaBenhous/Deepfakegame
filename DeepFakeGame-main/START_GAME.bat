@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0START_GAME.ps1"
if errorlevel 1 (
  echo.
  echo The game launcher stopped with an error.
  pause
)
