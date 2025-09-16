@echo off
REM SQL Server Data Import Utility - GUI Launcher
REM Double-click this file to start the user-friendly interface

echo Starting SQL Server Data Import Utility...
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available on this system.
    echo Please install PowerShell to use this utility.
    pause
    exit /b 1
)

REM Launch the GUI
powershell -ExecutionPolicy Bypass -File "%~dp0Import-GUI.ps1"

if errorlevel 1 (
    echo.
    echo The GUI failed to start. You may need to:
    echo 1. Run as Administrator
    echo 2. Enable PowerShell script execution
    echo 3. Install required PowerShell modules
    echo.
    echo Press any key to try the command-line version...
    pause >nul
    powershell -ExecutionPolicy Bypass -File "%~dp0Import-CLI.ps1"
)

pause