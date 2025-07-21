@echo off
REM YouTube Transcript MCP Server - Universal Installer (Windows)
REM Simple wrapper for the PowerShell installer

echo YouTube Transcript MCP Server Installer
echo =======================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: PowerShell is required but not found.
    echo Please install PowerShell 5.0 or higher.
    pause
    exit /b 1
)

REM Run the PowerShell installer with proper execution policy
echo Starting installation...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0install-mcp-universal-no-git.ps1" %*

REM Check if installation succeeded
if %errorlevel% neq 0 (
    echo.
    echo Installation failed!
    echo Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Installation completed successfully!
echo.
pause