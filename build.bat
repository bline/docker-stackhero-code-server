@echo off
REM Call the PowerShell script using ExecutionPolicy Bypass
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"

REM Optionally pause the window so you can see the output
pause
