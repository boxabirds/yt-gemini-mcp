@echo off
REM Universal MCP Installer - Windows Entry Point

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: PowerShell is required but not found
    echo Please install PowerShell 5.0 or higher
    exit /b 1
)

REM Check PowerShell version - FIXED
for /f %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_MAJOR=%%i
if %PS_MAJOR% LSS 5 (
    echo Error: PowerShell 5.0 or higher is required
    echo Current version is too old
    exit /b 1
)

REM Run PowerShell installer with bypass policy
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install-mcp-universal.ps1" %*