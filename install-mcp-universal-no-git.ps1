# YouTube Transcript MCP Server - Universal Installer (No Git Required)
# This is a completely self-contained script that can be shared as a GitHub Gist
#
# Usage:
#   iwr -useb https://gist.github.com/YOUR_GIST_ID/raw/install-mcp-universal-no-git.ps1 | iex
#   OR
#   Invoke-WebRequest -UseBasicParsing https://gist.github.com/YOUR_GIST_ID/raw/install-mcp-universal-no-git.ps1 | Invoke-Expression
#   OR
#   Download and run: powershell -ExecutionPolicy Bypass -File install-mcp-universal-no-git.ps1
#
# Supports: Windows 10/11, Windows Server 2016+
# Requirements: PowerShell 5.0+, Python 3

#Requires -Version 5.0

param(
    [string]$RepoBase = "https://raw.githubusercontent.com/boxabirds/yt-gemini-mcp/main",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Configuration
$SERVER_URL = "$RepoBase/youtube_transcript_server_fastmcp.py"
$INSTALLER_VERSION = "1.0.0"
$INSTALLER_DIR = "$env:LOCALAPPDATA\.mcp-installer"
$SERVERS_DIR = "$INSTALLER_DIR\servers"

# Logging functions
function Write-Success { 
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $args 
}

function Write-Error { 
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $args 
}

function Write-Warning { 
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $args 
}

# Download file
function Download-File {
    param(
        [string]$Url,
        [string]$Output
    )
    
    Write-Success "Downloading from: $Url"
    
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -UseBasicParsing
        return $true
    } catch {
        Write-Error "Failed to download $Url : $_"
        return $false
    }
}

# Check dependencies
function Test-Dependencies {
    $missing = @()
    
    # Check for Python
    $pythonCmd = Get-PythonCommand -Silent
    if (-not $pythonCmd) {
        $missing += "Python 3"
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missing -join ', ')"
        Write-Host ""
        Write-Host "Installation instructions:"
        
        if ($missing -contains "Python 3") {
            Write-Host "  Python 3:"
            Write-Host "    Download from: https://www.python.org/downloads/"
            Write-Host "    Make sure to check 'Add Python to PATH' during installation"
        }
        
        exit 1
    }
}

# Detect Python command
function Get-PythonCommand {
    param([switch]$Silent)
    
    $pythonCmd = $null
    $pythonVersion = $null
    
    foreach ($cmd in @("python3", "python", "py")) {
        try {
            $null = Get-Command $cmd -ErrorAction Stop
            $result = & $cmd -c "import sys; sys.exit(0 if sys.version_info.major >= 3 else 1)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonCmd = $cmd
                $pythonVersion = & $cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                break
            }
        } catch {
            # Continue to next candidate
        }
    }
    
    if (-not $pythonCmd -and -not $Silent) {
        Write-Error "Python 3 is required but not found"
        Write-Host "Please install Python 3 from https://www.python.org/downloads/"
        exit 1
    }
    
    if ($pythonCmd -and -not $Silent) {
        Write-Success "Found Python: $pythonCmd (version $pythonVersion)"
    }
    
    return $pythonCmd
}

# Detect installed clients
function Get-InstalledClients {
    $clients = @()
    
    # Check for Gemini CLI
    if (Test-Path "$env:USERPROFILE\.gemini") {
        $clients += "gemini"
    }
    
    # Check for Claude Code
    try {
        $null = Get-Command claude -ErrorAction Stop
        $clients += "claude"
    } catch {}
    
    # Check for Windsurf
    if ((Test-Path "$env:APPDATA\Codeium\Windsurf") -or 
        (Test-Path "$env:LOCALAPPDATA\Windsurf") -or
        (Test-Path "$env:USERPROFILE\.config\Windsurf")) {
        $clients += "windsurf"
    }
    
    # Check for Cursor
    if (Test-Path "$env:USERPROFILE\.cursor") {
        $clients += "cursor"
    }
    
    return $clients
}

# Initialize installer directory
function Initialize-InstallerDirectory {
    if (-not (Test-Path $INSTALLER_DIR)) {
        New-Item -ItemType Directory -Path $INSTALLER_DIR -Force | Out-Null
    }
    if (-not (Test-Path $SERVERS_DIR)) {
        New-Item -ItemType Directory -Path $SERVERS_DIR -Force | Out-Null
    }
}


# Get or request API key
function Request-ApiKey {
    param(
        [string]$KeyName
    )
    
    # Always prompt for key
    Write-Host ""
    Write-Host "📝 Setting up Gemini API key for MCP server" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This MCP server needs its own Gemini API key that will be stored"
    Write-Host "in each AI assistant's configuration. This allows you to:"
    Write-Host "  • Manage this key separately from your shell environment"
    Write-Host "  • Revoke access without affecting other applications"
    Write-Host "  • Track usage specifically for YouTube video analysis"
    Write-Host ""
    Write-Host "Get your API key at: https://aistudio.google.com/apikey" -ForegroundColor Cyan
    Write-Host ""
    $keyValue = Read-Host "Enter your Gemini API key" -AsSecureString
    
    # Convert SecureString back to plain text
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyValue)
    $keyValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    if ([string]::IsNullOrWhiteSpace($keyValue)) {
        Write-Error "API key cannot be empty"
        exit 1
    }
    
    return $keyValue
}

# Install for JSON-based clients
function Install-JsonClient {
    param(
        [string]$Client,
        [string]$ConfigPath,
        [string]$ServerName,
        [hashtable]$ServerConfig
    )
    
    # Ensure directory exists
    $configDir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    $fileStatus = "new"
    $existingServer = $false
    
    # Load or create configuration
    $config = if (Test-Path $ConfigPath) {
        $fileStatus = "updated"
        try {
            $loadedConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            # Check if server already exists
            if ($loadedConfig.mcpServers -and $loadedConfig.mcpServers.$ServerName) {
                $existingServer = $true
            }
            $loadedConfig
        } catch {
            Write-Warning "Existing config is invalid, creating new one"
            [PSCustomObject]@{ mcpServers = @{} }
        }
    } else {
        [PSCustomObject]@{ mcpServers = @{} }
    }
    
    # Ensure mcpServers property exists and is the right type
    if (-not $config.mcpServers) {
        $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    
    # Add server configuration
    $config.mcpServers | Add-Member -NotePropertyName $ServerName -NotePropertyValue $ServerConfig -Force
    
    # Save configuration with proper formatting
    try {
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        if ($existingServer) {
            Write-Success "Updated existing $ServerName for $Client"
        } else {
            Write-Success "Installed $ServerName for $Client"
        }
        Write-Host "  📄 Config file: $ConfigPath ($fileStatus)" -ForegroundColor Gray
        return $true
    } catch {
        Write-Error "Failed to save configuration for $Client`: $_"
        return $false
    }
}

# Install for Claude Code using CLI
function Install-Claude {
    param(
        [string]$ServerName,
        [string]$Command,
        [string[]]$Args,
        [hashtable]$Env
    )
    
    # Check if server already exists
    $existingServer = $false
    try {
        $existingServers = & claude mcp list 2>$null
        if ($existingServers -match $ServerName) {
            $existingServer = $true
        }
    } catch { }
    
    $cmd = @("claude", "mcp", "add", $ServerName, "-s", "user")
    
    if ($Command) {
        $cmd += $Command
        if ($Args) {
            $cmd += $Args
        }
    }
    
    # Better approach for environment variables
    $originalEnv = @{}
    foreach ($key in $Env.Keys) {
        $originalEnv[$key] = [Environment]::GetEnvironmentVariable($key, "Process")
        [Environment]::SetEnvironmentVariable($key, $Env[$key], "Process")
    }
    
    try {
        # Run claude command
        $result = & $cmd[0] $cmd[1..($cmd.Length-1)] 2>&1
        $success = $LASTEXITCODE -eq 0
        
        if ($success) {
            if ($existingServer) {
                Write-Success "Updated existing $ServerName for Claude Code"
            } else {
                Write-Success "Installed $ServerName for Claude Code"
            }
            
            # Claude stores configs in platform-specific locations
            $configLocations = @(
                "$env:LOCALAPPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json",
                "$env:LOCALAPPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json",
                "$env:APPDATA\Code - Insiders\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json",
                "$env:APPDATA\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json"
            )
            
            foreach ($loc in $configLocations) {
                if (Test-Path $loc) {
                    Write-Host "  📄 Config file: $loc" -ForegroundColor Gray
                    break
                }
            }
            
            return $true
        } else {
            Write-Error "Claude command failed with exit code: $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-Error "Failed to install for Claude Code: $_"
        Write-Warning "You may need to install manually using: claude mcp add"
        return $false
    } finally {
        # Restore original environment
        foreach ($key in $Env.Keys) {
            if ($null -ne $originalEnv[$key]) {
                [Environment]::SetEnvironmentVariable($key, $originalEnv[$key], "Process")
            } else {
                [Environment]::SetEnvironmentVariable($key, $null, "Process")
            }
        }
    }
}

# Download and install server
function Install-Server {
    param(
        [string]$ServerUrl,
        [string]$ServerPath
    )
    
    # Try multiple sources if the first fails
    $sources = @(
        $ServerUrl,
        "https://cdn.jsdelivr.net/gh/yourusername/yt-gemini-mcp@main/youtube_transcript_server_fastmcp.py",
        "https://gitcdn.link/repo/yourusername/yt-gemini-mcp/main/youtube_transcript_server_fastmcp.py"
    )
    
    $downloaded = $false
    foreach ($source in $sources) {
        if (Download-File -Url $source -Output $ServerPath) {
            $downloaded = $true
            break
        }
    }
    
    if (-not $downloaded) {
        Write-Error "Failed to download server from all sources"
        exit 1
    }
    
    # Verify it's valid Python
    $pythonCmd = Get-PythonCommand
    $validateResult = & $pythonCmd -m py_compile $ServerPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Downloaded server script has syntax errors"
        Remove-Item $ServerPath -Force
        exit 1
    }
}

# Create virtual environment
function New-VirtualEnvironment {
    param(
        [string]$VenvDir,
        [string]$PythonCmd
    )
    
    if (-not (Test-Path $VenvDir)) {
        Write-Success "Creating virtual environment..."
        $result = & $PythonCmd -m venv $VenvDir 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Created virtual environment at $VenvDir"
        } else {
            Write-Error "Failed to create virtual environment"
            return $false
        }
    } else {
        Write-Success "Using existing virtual environment at $VenvDir"
    }
    
    # Upgrade pip in the venv
    $venvPython = Join-Path $VenvDir "Scripts\python.exe"
    $result = & $venvPython -m pip install --quiet --upgrade pip 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to upgrade pip in virtual environment"
    }
    
    return $true
}

# Install Python dependencies in virtual environment
function Install-PythonDependencies {
    param(
        [string]$VenvDir,
        [string]$PythonCmd
    )
    
    Write-Success "Installing Python dependencies in virtual environment..."
    
    # Create a temporary requirements file
    $tempRequirements = [System.IO.Path]::GetTempFileName()
    @"
mcp>=1.0.0
fastmcp>=0.1.0
google-genai>=0.8.0
"@ | Set-Content $tempRequirements
    
    # Install dependencies in venv
    $venvPip = Join-Path $VenvDir "Scripts\pip.exe"
    $result = & $venvPip install --quiet -r $tempRequirements 2>&1
    $success = $LASTEXITCODE -eq 0
    
    if ($success) {
        Write-Success "Python dependencies installed successfully"
    } else {
        Write-Warning "Failed to install some Python dependencies"
        Write-Host "You may need to install them manually:"
        Write-Host "  $venvPip install mcp fastmcp google-genai"
    }
    
    Remove-Item $tempRequirements -Force
}

# Create test script
function New-TestScript {
    param(
        [string]$PythonCmd,
        [string]$ServerScript,
        [string]$ApiKey
    )
    
    $testScript = Join-Path $INSTALLER_DIR "test-server.ps1"
    
    @"
# YouTube Transcript MCP Server Test Script
# WARNING: This script contains your API key in plain text

`$env:GEMINI_API_KEY = "$ApiKey"
Write-Host "Testing YouTube Transcript MCP Server..."
Write-Host "Press Ctrl+C to stop"
Write-Host ""
& "$PythonCmd" "$ServerScript"
"@ | Set-Content $testScript -Encoding UTF8
    
    # Also create a batch file for easier execution
    $testBatch = Join-Path $INSTALLER_DIR "test-server.cmd"
    
    @"
@echo off
REM YouTube Transcript MCP Server Test Script
REM WARNING: Contains API key - do not share
powershell -ExecutionPolicy Bypass -File "$testScript"
"@ | Set-Content $testBatch -Encoding UTF8
}

# Main installation
function Install-Main {
    Write-Success "YouTube Transcript MCP Server Installer v$INSTALLER_VERSION"
    Write-Host ("=" * 50)
    
    # Check dependencies
    Test-Dependencies
    
    # Get Gemini API key
    $geminiKey = Request-ApiKey -KeyName "GEMINI_API_KEY"
    
    # Detect Python
    $pythonCmd = Get-PythonCommand
    
    # Initialize directories
    Initialize-InstallerDirectory
    
    # Download server
    Write-Success "Downloading MCP server..."
    $serverScript = Join-Path $SERVERS_DIR "youtube_transcript_server.py"
    
    # Check if server already exists
    $serverStatus = "new"
    if (Test-Path $serverScript) {
        $serverStatus = "updated"
    }
    
    Install-Server -ServerUrl $SERVER_URL -ServerPath $serverScript
    Write-Host "  📄 Server script: $serverScript ($serverStatus)" -ForegroundColor Gray
    
    # Create virtual environment
    $venvDir = Join-Path $INSTALLER_DIR "venv"
    if (-not (New-VirtualEnvironment -VenvDir $venvDir -PythonCmd $pythonCmd)) {
        Write-Error "Failed to create virtual environment"
        exit 1
    }
    Write-Host "  📄 Virtual environment: $venvDir" -ForegroundColor Gray
    
    # Install Python dependencies
    Install-PythonDependencies -VenvDir $venvDir -PythonCmd $pythonCmd
    
    # Use venv Python for running the server
    $venvPython = Join-Path $venvDir "Scripts\python.exe"
    
    # Detect installed clients
    Write-Success "Detecting installed AI assistants..."
    $clients = Get-InstalledClients
    
    if ($clients.Count -eq 0) {
        Write-Error "No supported AI assistants detected"
        Write-Host ""
        Write-Host "Supported clients:"
        Write-Host "  - Gemini CLI"
        Write-Host "  - Claude Code"  
        Write-Host "  - Windsurf"
        Write-Host "  - Cursor"
        exit 1
    }
    
    Write-Success "Found $($clients.Count) client(s): $($clients -join ', ')"
    
    # Install for each client
    $successCount = 0
    foreach ($client in $clients) {
        Write-Host ""
        Write-Success "Configuring $client..."
        
        $success = switch ($client) {
            "gemini" {
                $configPath = Join-Path $env:USERPROFILE ".gemini\settings.json"
                $serverConfig = @{
                    command = $venvPython
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "ask-youtube" -ServerConfig $serverConfig
            }
            
            "claude" {
                Install-Claude -ServerName "ask-youtube" -Command $venvPython `
                    -Args @($serverScript) -Env @{ GEMINI_API_KEY = $geminiKey }
            }
            
            "windsurf" {
                $configPath = if (Test-Path "$env:LOCALAPPDATA\Windsurf") {
                    Join-Path $env:LOCALAPPDATA "Windsurf\mcp_config.json"
                } elseif (Test-Path "$env:USERPROFILE\.config\Windsurf") {
                    Join-Path $env:USERPROFILE ".config\Windsurf\mcp_config.json"
                } else {
                    Join-Path $env:APPDATA "Codeium\Windsurf\mcp_config.json"
                }
                
                $serverConfig = @{
                    command = $venvPython
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "ask-youtube" -ServerConfig $serverConfig
            }
            
            "cursor" {
                $configPath = Join-Path $env:USERPROFILE ".cursor\mcp.json"
                $serverConfig = @{
                    command = $venvPython
                    args = @($serverScript)
                    env = @{
                        GEMINI_API_KEY = $geminiKey
                    }
                }
                Install-JsonClient -Client $client -ConfigPath $configPath `
                    -ServerName "ask-youtube" -ServerConfig $serverConfig
            }
        }
        
        if ($success) {
            $successCount++
        }
    }
    
    # Create test script
    New-TestScript -PythonCmd $venvPython -ServerScript $serverScript -ApiKey $geminiKey
    
    Write-Host ""
    if ($successCount -gt 0) {
        Write-Success "Installation complete! ($successCount/$($clients.Count) clients configured)"
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "1. Restart any running AI assistant applications"
        Write-Host "2. The server will be available as 'ask-youtube' in configured clients"
        Write-Host "3. Test the server with: $INSTALLER_DIR\test-server.cmd"
        
        if ($successCount -lt $clients.Count) {
            Write-Host ""
            Write-Warning "Some clients failed to configure. Check the errors above."
        }
    } else {
        Write-Error "Installation failed for all clients"
        exit 1
    }
}

# Run main installation
Install-Main