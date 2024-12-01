@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell script as administrator
powershell -ExecutionPolicy Bypass -File "%~dp0dependencies\setup.ps1"

pause
exit /b
