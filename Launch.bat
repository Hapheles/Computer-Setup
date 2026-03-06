@echo off
title IPC Setup Launcher
echo ========================================
echo    IPC Setup Utility
echo ========================================
echo.
echo This will temporarily bypass PowerShell security
echo to run the setup utility.
echo.
pause

echo.
echo Starting IPC Setup...
powershell -ExecutionPolicy Bypass -File "%~dp0Main.ps1"
pushd "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0ps2DLC\loadGAC.ps1"

echo.
echo Setup completed.

pause
