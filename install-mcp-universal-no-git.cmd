@echo off
REM YouTube Transcript MCP Server - Universal Installer Entry Point (Windows)
REM This batch file detects and runs the appropriate installer
REM
REM Usage:
REM   install-mcp-universal-no-git.cmd

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: PowerShell is required but not found
    echo Please install PowerShell 5.0 or higher
    pause
    exit /b 1
)

REM Check PowerShell version
for /f %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major"') do set PS_MAJOR=%%i
if %PS_MAJOR% LSS 5 (
    echo Error: PowerShell 5.0 or higher is required
    echo Current version is too old
    pause
    exit /b 1
)

echo YouTube Transcript MCP Server Installer
echo ======================================
echo.
echo This installer will:
echo   1. Download the MCP server from GitHub
echo   2. Configure it for your AI assistants
echo   3. Set up your Gemini API key
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul

REM Download and run the PowerShell installer
echo.
echo Downloading installer...
powershell -ExecutionPolicy Bypass -Command "& { iwr -useb 'https://raw.githubusercontent.com/yourusername/yt-gemini-mcp/main/install-mcp-universal-no-git.ps1' | iex }"

if %errorlevel% neq 0 (
    echo.
    echo Installation failed. Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Installation complete!
pause